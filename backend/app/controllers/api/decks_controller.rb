# Decks do jogador logado (escopo 3.3; ADR 0009). Toda resposta com um deck traz se ele é
# válido e os erros do Decks::Validator: deck incompleto pode ser salvo como rascunho.
class Api::DecksController < Api::BaseController
  before_action :require_authentication
  before_action :set_deck, only: %i[show update destroy export]
  before_action :check_deck_limit, only: %i[create import]

  class InvalidCards < StandardError; end
  rescue_from InvalidCards do
    render_error(:unprocessable_content, "Confira o deck.", { cards: [ "precisa ser uma lista de até #{Decks::Editor::MAX_ROWS} cartas" ] })
  end

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

  # POST /api/decks/import: { name, kind: "ydk" ou "text", content }. Cria o deck com o
  # que achou no pool e devolve os avisos do que ficou de fora.
  def import
    import = Decks::Import.new(current_user, params.permit(:name, :kind, :content))
    if import.save
      render json: { data: detail(import.deck), meta: { warnings: import.warnings } }, status: :created
    else
      render_error(:unprocessable_content, import.error || "Confira o deck.", import.deck.errors.to_hash.presence)
    end
  end

  # GET /api/decks/:id/export.ydk ou .txt: o arquivo para baixar.
  def export
    rows = @deck.deck_cards.includes(:card).order(:id)
    case params[:format]
    when "ydk"
      file = Decks::Ydk.dump(rows.map { |row| { section: row.section, code: row.card.passcode || row.card.engine_code, quantity: row.quantity } })
    when "txt"
      file = Decks::Text.dump(rows.map { |row| { section: row.section, name: row.card.name, quantity: row.quantity, destiny: row.destiny } })
    else
      return not_found
    end
    send_data file, filename: "#{@deck.name}.#{params[:format]}", type: "text/plain"
  end

  private

  def check_deck_limit
    return if current_user.decks.count < Deck::LIMIT_PER_USER

    render_error(:unprocessable_content, "Você chegou ao limite de #{Deck::LIMIT_PER_USER} decks.")
  end

  def set_deck
    @deck = current_user.decks.find(params[:id])
  end

  # As cartas do pedido, ou nil quando não vieram (o deck mantém as que tem). Precisa ser
  # uma lista de objetos: outra coisa vira erro, em vez de apagar as cartas do deck.
  def card_params
    rows = params[:cards]
    return if rows.nil?
    raise InvalidCards unless rows.is_a?(Array) && rows.size <= Decks::Editor::MAX_ROWS && rows.all?(ActionController::Parameters)

    rows.map { |row| row.permit(:card_id, :section, :quantity, :destiny).to_h.symbolize_keys }
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
