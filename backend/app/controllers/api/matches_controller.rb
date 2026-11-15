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

  # GET /api/matches/:id
  def show
    render json: { data: state(Matches::Game.new(@match)) }
  end

  # POST /api/matches/:id/responses: { seq, response }. seq é quantas respostas o jogador
  # viu: se a partida andou desde então, 409 e a tela busca a mesa de novo.
  def respond
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

  private

  def set_match(scope = Match)
    @match = scope.includes(:players).find(params[:id])
    @player = @match.players.find { |player| player.user_id == current_user.id } || raise(ActiveRecord::RecordNotFound)
  end

  def choice_params
    params.fetch(:response, {}).permit(:command, :index, :yes, :cancel, :position, :mask, :code, :hand,
                                       indexes: [], places: [], counts: [], order: []).to_h.symbolize_keys
  end

  # A partida vista por um time: quem joga, quantas respostas já houve e a mesa.
  def state(game, team = @player.team)
    { id: @match.id, status: @match.status, winner_team: @match.winner_team, seq: @match.responses.size, you: team,
      players: @match.players.map { |player| { team: player.team, nickname: nicknames.fetch(player.user_id, "Duelista") } },
      view: game.view(team) }
  end

  # Os apelidos numa consulta só; quem apagou a conta vira "Duelista".
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
