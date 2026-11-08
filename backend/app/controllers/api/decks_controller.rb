# Decks do jogador logado (escopo 3.3; ADR 0009). Toda resposta com um deck traz se ele é
# válido e os erros do Decks::Validator: deck incompleto pode ser salvo como rascunho.
class Api::DecksController < Api::BaseController
  before_action :require_authentication
  before_action :set_deck, only: %i[show update destroy]

  # GET /api/decks
  def index
    decks = current_user.decks.order(:name).includes(:deck_cards)
    render json: { data: decks.map { |deck| summary(deck) } }
  end

  # GET /api/decks/:id
  def show
    render json: { data: detail(@deck) }
  end

  # POST /api/decks
  def create
    if current_user.decks.count >= Deck::LIMIT_PER_USER
      return render_error(:unprocessable_content, "Você chegou ao limite de #{Deck::LIMIT_PER_USER} decks.")
    end

    save(current_user.decks.build, :created)
  end

  # PATCH /api/decks/:id
  def update
    save(@deck, :ok)
  end

  # DELETE /api/decks/:id
  def destroy
    @deck.destroy
    head :no_content
  end

  # POST /api/decks/validate: as regras do deck, sem salvar nada.
  def validate
    entries = Decks::Editor.merge(card_params.to_a).map { |row| Decks::Entry.new(**row) }
    validator = Decks::Validator.build(current_user, entries)
    render json: { data: { valid: validator.valid?, errors: validator.errors } }
  end

  private

  def set_deck
    @deck = current_user.decks.find(params[:id])
  end

  # As cartas do pedido, ou nil quando não vieram (o deck mantém as que tem).
  def card_params
    params.permit(cards: %i[card_id section quantity destiny])[:cards]&.map { |row| row.to_h.symbolize_keys }
  end

  def save(deck, status)
    if Decks::Editor.new(deck).save(name: params[:name], cards: card_params)
      render json: { data: detail(deck) }, status:
    else
      render_error(:unprocessable_content, "Confira o deck.", deck.errors.to_hash)
    end
  end

  def summary(deck)
    counts = DeckCard::SECTIONS.index_with { |section| deck.deck_cards.select { |row| row.section == section }.sum(&:quantity) }
    { id: deck.id, name: deck.name, updated_at: deck.updated_at, counts: }
  end

  def detail(deck)
    validator = Decks::Validator.for(deck)
    cards = deck.deck_cards.order(:id).map { |row| row.slice(:card_id, :section, :quantity, :destiny) }
    { id: deck.id, name: deck.name, updated_at: deck.updated_at, cards:, valid: validator.valid?, errors: validator.errors }
  end
end
