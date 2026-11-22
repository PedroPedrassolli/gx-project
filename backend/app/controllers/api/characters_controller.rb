# Duelos contra personagens (escopo 3.10; ADR 0013): a lista, com o que o jogador já liberou e
# venceu, e o começo do duelo contra um deles.
class Api::CharactersController < Api::BaseController
  before_action :require_authentication

  # GET /api/characters: os personagens na ordem. O duelo em andamento vem na sessão.
  def index
    progress = Characters::Progress.new(current_user)
    signatures = Card.where(name: Characters::Roster.all.map(&:signature)).index_by(&:name)
    characters = Characters::Roster.all.map { |character| character_json(character, progress, signatures[character.signature]) }
    render json: { data: { characters: } }
  end

  # POST /api/characters/:id/duels: { deck_id }. Começa o duelo com um deck do jogador e devolve
  # a partida (a tela vai para a mesa).
  def duel
    character = Characters::Roster.find(params[:id].to_s) || raise(ActiveRecord::RecordNotFound)
    deck = current_user.decks.find(params[:deck_id].to_s)
    match = Characters::Challenge.new(current_user, character, deck).call
    render json: { data: { match_id: match.id } }, status: :created
  rescue Characters::Challenge::Refused => error
    render_error(:unprocessable_content, error.message)
  end

  private

  def character_json(character, progress, card)
    wins = progress.wins(character)
    unlocked = progress.unlocked?(character)
    { id: character.id, position: character.position, name: character.name, description: character.description,
      group: { id: character.group.id, name: character.group.name }, deck: character.deck.name, bonus: character.victory_bonus,
      signature: card && { id: card.id, name: card.name, name_pt: card.name_pt, image: card.image_code }.compact,
      wins:, status: status(wins, unlocked),
      unlock_hint: ("Vença #{Characters::Roster.before(character).name} para liberar." unless unlocked) }.compact
  end

  def status(wins, unlocked)
    return "beaten" if wins.positive?

    unlocked ? "unlocked" : "locked"
  end
end
