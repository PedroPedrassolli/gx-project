# Salas de duelo (escopo 3.6 e 5.6; ADR 0010). Cada mudança avisa quem está na sala pelo
# tempo real (room.updated, com a sala vista por aquele jogador); quem está sem tempo real
# consulta GET /api/rooms/:code.
class Api::RoomsController < Api::BaseController
  before_action :require_authentication
  before_action :set_room, only: %i[join leave ready kick]

  # GET /api/rooms: as salas públicas esperando gente, as mais novas primeiro.
  def index
    rooms = Room.listed.includes(:owner).order(created_at: :desc).limit(50).to_a
    # Quantos em cada sala, numa consulta só (sem carregar os jogadores).
    counts = RoomPlayer.where(room_id: rooms.map(&:id)).group(:room_id).count
    render json: { data: rooms.map { |room| summary(room, counts.fetch(room.id, 0)) } }
  end

  # GET /api/rooms/:code
  def show
    room = Room.includes(players: :user).find_by!(code: code_param)
    render json: { data: room_json(room, current_user.id) }
  end

  # POST /api/rooms: cria a sala com as opções e senta o dono no primeiro lugar. Quem estava
  # esperando em outra sala sai dela antes.
  def create
    return in_duel if in_duel?

    leave_current_room
    room = Room.new(owner: current_user, code: Room.new_code, **room_params)
    Room.transaction do
      room.save!
      room.players.create!(user: current_user, seat: 0)
    end
    render json: { data: room_json(room, current_user.id) }, status: :created
  end

  # POST /api/rooms/:code/join: senta no primeiro lugar livre (quem já está nela, fica).
  def join
    unless @room.players.exists?(user: current_user)
      return in_duel if in_duel?
      return render_error(:unprocessable_content, "Esta sala já está em duelo.") unless @room.waiting?
      return full_room unless @room.free_seat

      leave_current_room
      @room.players.create!(user: current_user, seat: @room.free_seat)
    end
    render json: { data: room_json(broadcast_update(@room.id), current_user.id) }
  rescue ActiveRecord::RecordNotUnique
    # Duas pessoas pegaram o último lugar ao mesmo tempo: o índice deixa só uma.
    full_room
  end

  # POST /api/rooms/:code/leave: sai da sala. Se o dono sai, a sala fecha para todos. No meio
  # do duelo, não: primeiro se desiste dele (na mesa).
  def leave
    player = @room.players.find_by!(user: current_user)
    return render_error(:unprocessable_content, "Desista do duelo antes de sair da sala.") unless @room.waiting?

    remove(player)
    head :no_content
  end

  # POST /api/rooms/:code/ready: escolhe o deck e fica pronto (ou deixa de ficar). O deck
  # precisa valer com as regras da sala.
  def ready
    player = @room.players.find_by!(user: current_user)
    return render_error(:unprocessable_content, "Esta sala já está em duelo.") unless @room.waiting?

    if ActiveModel::Type::Boolean.new.cast(params[:ready])
      deck = current_user.decks.find(params[:deck_id].to_s)
      validator = Decks::Validator.for(deck, banlist: @room.banlist)
      return render_error(:unprocessable_content, "Este deck não vale nesta sala.", { deck: validator.errors }) unless validator.valid?

      player.update!(deck:, ready: true)
      # O último a ficar pronto começa o duelo: quem estava na sala vai para a partida.
      if (match = Matches::Start.new(@room).call)
        publish(match.players.map(&:user_id), "match.started") { { code: @room.code, match_id: match.id } }
      end
    else
      player.update!(ready: false)
    end
    render json: { data: room_json(broadcast_update(@room.id), current_user.id) }
  end

  # POST /api/rooms/:code/kick: o dono tira alguém da sala antes de começar.
  def kick
    return render_error(:forbidden, "Só quem criou a sala pode tirar alguém.") unless @room.owner_id == current_user.id
    return render_error(:unprocessable_content, "Esta sala já está em duelo.") unless @room.waiting?

    player = @room.players.where.not(user: current_user).find_by!(user_id: params[:user_id].to_s)
    remove(player)
    publish([ player.user_id ], "room.kicked") { { code: @room.code } }
    head :no_content
  end

  private

  def code_param = params[:code].to_s.upcase

  def set_room
    @room = Room.find_by!(code: code_param)
  end

  def room_params = params.permit(:public, :banlist, :destiny_draw).to_h.symbolize_keys

  # Durante o duelo, o jogador não troca de sala. O duelo com o prazo vencido (os dois saíram
  # da mesa) acaba aqui, por tempo, e não prende ninguém (escopo 3.7: desconexão vira derrota).
  def in_duel?
    room = current_user.room_player&.room
    return false if room.nil? || room.waiting?

    match = room.matches.find_by(status: "dueling")
    return true unless match

    !finish_if_expired(match)
  end

  # Travada, para duas consultas não encerrarem a mesma partida. true se encerrou.
  def finish_if_expired(match)
    game = Matches::Game.new(match)
    return false unless game.expired?

    Match.transaction do
      match.lock!
      game.expire!
    end
    current_user.reload_room_player
    true
  end

  def in_duel = render_error(:unprocessable_content, "Você está num duelo.")

  def full_room = render_error(:unprocessable_content, "A sala está cheia.")

  def leave_current_room
    player = current_user.room_player
    remove(player) if player
    current_user.reload_room_player
  end

  def remove(player)
    room = player.room
    if room.owner_id == player.user_id
      members = room.players.pluck(:user_id) - [ player.user_id ]
      room.destroy!
      publish(members, "room.closed") { { code: room.code } }
    else
      player.destroy!
      broadcast_update(room.id)
    end
  end

  # Lê a sala de novo, com os jogadores, avisa cada um e devolve a sala lida.
  def broadcast_update(room_id)
    room = Room.includes(players: :user).find(room_id)
    publish(room.players.map(&:user_id), "room.updated") { |user_id| room_json(room, user_id) }
    room
  end

  # Falha do Ably não derruba o pedido: quem não recebeu vê na próxima consulta.
  def publish(user_ids, event)
    user_ids.each { |user_id| Realtime::Publisher.current.publish(user_id:, event:, data: yield(user_id)) }
  rescue Realtime::AblyPublisher::Error => error
    Rails.logger.warn("#{event} não saiu: #{error.message}")
  end

  def summary(room, players)
    { code: room.code, owner: room.owner.nickname, players:, seats: room.seats,
      banlist: room.banlist, destiny_draw: room.destiny_draw }
  end

  # A sala vista por um jogador: o deck escolhido só aparece para o dono dele.
  def room_json(room, viewer_id)
    players = room.players.map do |player|
      { seat: player.seat, user_id: player.user_id, nickname: player.user.nickname, ready: player.ready,
        deck_chosen: player.deck_id.present?, deck_id: (player.deck_id if player.user_id == viewer_id) }.compact
    end
    # Em duelo, a sala diz qual é a partida (quem recarregar a página vai para ela).
    match_id = room.matches.where(status: "dueling").pick(:id) unless room.waiting?
    room.slice(:code, :public, :mode, :best_of, :banlist, :destiny_draw, :status, :owner_id)
        .merge(seats: room.seats, players:, match_id:).compact
  end
end
