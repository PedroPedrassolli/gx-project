# Partidas (escopo 5.4 e 5.6; ADR 0011): a mesa do jogador e a resposta dele à pergunta da
# vez. Depois de cada resposta, os outros recebem a mesa nova pelo tempo real (duel.updated).
class Api::MatchesController < Api::BaseController
  before_action :require_authentication
  before_action :set_match

  rescue_from Duel::ResponseEncoder::InvalidChoice, Duel::Session::InvalidResponse do
    render_error(:unprocessable_content, "Essa jogada não vale agora.")
  end
  rescue_from Matches::Game::NotYourTurn do |error|
    render_error(:conflict, error.message)
  end

  # GET /api/matches/:id. O prazo vencido encerra a partida aqui (não há processo esperando o
  # relógio): quem consulta fica sabendo, e o outro recebe a mesa nova.
  def show
    game = Matches::Game.new(@match)
    publish_to_others(game) if expire(game)
    render json: { data: state(game) }
  end

  # POST /api/matches/:id/responses: { seq, response }. seq é quantas respostas o jogador
  # viu: se a partida andou desde então, 409 e a tela busca a mesa de novo.
  def respond
    game = Matches::Game.new(@match)
    if expire(game)
      publish_to_others(game)
      return render_error(:conflict, "O tempo acabou.")
    end

    game = Match.transaction do
      # A partida travada: duas respostas ao mesmo tempo esperam uma pela outra.
      set_match(Match.lock)
      unless params[:seq].to_s == @match.responses.size.to_s
        raise Matches::Game::NotYourTurn, "A mesa mudou: confira e jogue de novo."
      end

      Matches::Game.new(@match).tap { |game| game.respond!(@player.team, choice_params) }
    end
    publish_to_others(game)
    render json: { data: state(game) }
  end

  # GET /api/matches/:id/replay?turn=N: o replay de um turno, só depois do fim do duelo. A
  # partida acabada não muda: o navegador guarda a resposta por um dia.
  def replay
    return render_error(:conflict, "O replay fica pronto quando o duelo acaba.") if @match.dueling?

    replay = Matches::Replay.new(@match)
    turn = params[:turn].to_i.clamp(1, [ replay.turns, 1 ].max)
    expires_in 1.day, public: false
    render json: { data: { id: @match.id, turn:, turns: replay.turns, you: @player.team, winner_team: @match.winner_team,
                           finish_reason: @match.finish_reason, players:, frames: replay.frames(@player.team, turn) } }
  end

  # POST /api/matches/:id/surrender: quem desiste perde, e a sala volta a esperar.
  def surrender
    game = Match.transaction do
      set_match(Match.lock)
      Matches::Game.new(@match).tap { |game| game.surrender!(@player.team) }
    end
    publish_to_others(game)
    render json: { data: state(game) }
  end

  # POST /api/matches/:id/emotes: { emote }. Uma das frases fixas, para o outro ver por alguns
  # segundos (duel.emote). Também depois do fim: o "bom duelo" vem aí.
  def emote
    emote = params[:emote].to_s
    return render_error(:unprocessable_content, "Essa frase não existe.") unless MatchPlayer::EMOTES.include?(emote)
    if @player.emote_at && @player.emote_at > MatchPlayer::EMOTE_EVERY.ago
      return render_error(:too_many_requests, "Uma frase a cada #{MatchPlayer::EMOTE_EVERY.to_i} segundos.")
    end

    @player.update!(emote:, emote_at: Time.current)
    data = { id: @match.id }.merge(emote_json(@player))
    @match.players.reject { |player| player == @player || player.user_id.nil? }.each do |player|
      Realtime::Publisher.current.publish(user_id: player.user_id, event: "duel.emote", data:)
    end
    render json: { data: }
  rescue Realtime::AblyPublisher::Error => error
    Rails.logger.warn("duel.emote não saiu: #{error.message}")
    render json: { data: }
  end

  # POST /api/matches/:id/settings: { always_chain }. "Sempre perguntar" na corrente (escopo
  # 3.7): vale das próximas perguntas em diante. O navegador guarda a escolha e manda em cada
  # duelo.
  def settings
    @player.update!(always_chain: ActiveModel::Type::Boolean.new.cast(params[:always_chain]) || false)
    head :no_content
  end

  private

  # A frase recente de um jogador (quem consulta sem tempo real vê por EMOTE_SHOWN).
  def emote_json(player)
    return {} unless player.emote_at && player.emote_at > MatchPlayer::EMOTE_SHOWN.ago

    { team: player.team, emote: player.emote, emote_at: player.emote_at.iso8601(3) }
  end

  # Encerra a partida com o prazo vencido, travada, para duas consultas não encerrarem juntas.
  def expire(game)
    return false unless game.expired?

    Match.transaction do
      @match.lock!
      game.expire!
    end
  end

  def set_match(scope = Match)
    @match = scope.includes(:players).find(params[:id])
    @player = @match.players.find { |player| player.user_id == current_user.id } || raise(ActiveRecord::RecordNotFound)
  end

  def choice_params
    params.fetch(:response, {}).permit(:command, :index, :yes, :cancel, :position, :mask, :code, :hand,
                                       indexes: [], places: [], counts: [], order: []).to_h.symbolize_keys
  end

  # A partida vista por um time: quem joga, quantas respostas já houve, o relógio e a mesa.
  def state(game, team = @player.team)
    { id: @match.id, status: @match.status, winner_team: @match.winner_team, finish_reason: @match.finish_reason,
      seq: @match.responses.size, you: team, room_code: @match.room&.code,
      deadline_at: @match.deadline_at&.iso8601, turn_time_left: @match.turn_time_left,
      ends_at: @match.ends_at&.iso8601,
      always_chain: @match.players.find { |player| player.team == team }&.always_chain,
      # No fim, o DP que o jogador ganhou, linha por linha (GXP-85; Economy::DuelRewards).
      rewards: @match.players.find { |player| player.team == team }&.rewards,
      # Contra o computador: o personagem (ADR 0013).
      character: @match.bot&.character,
      players:, view: game.view(team) }
  end

  # O nome do personagem no lugar do computador; quem apagou a conta vira "Duelista".
  def players
    @match.players.map do |player|
      nickname = player.character ? Characters::Roster.find(player.character)&.name : nicknames[player.user_id]
      { team: player.team, nickname: nickname || "Duelista" }.merge(emote_json(player))
    end
  end

  # Os apelidos numa consulta só.
  def nicknames
    @nicknames ||= User.where(id: @match.players.map(&:user_id)).pluck(:id, :nickname).to_h
  end

  # Falha do Ably não desfaz a jogada: o outro vê na próxima consulta.
  def publish_to_others(game)
    @match.players.reject { |player| player == @player || player.user_id.nil? }.each do |player|
      Realtime::Publisher.current.publish(user_id: player.user_id, event: "duel.updated", data: state(game, player.team))
    end
  rescue Realtime::AblyPublisher::Error => error
    Rails.logger.warn("duel.updated não saiu: #{error.message}")
  end
end
