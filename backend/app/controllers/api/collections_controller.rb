# Coleção do jogador logado (escopo 3.2).
class Api::CollectionsController < Api::BaseController
  before_action :require_authentication

  # Quantas cartas dá para marcar como vistas de uma vez (o pool inteiro tem uns 3.500).
  MAX_SEEN = 5_000

  # GET /api/collection: as cartas, com quantidade, data de obtenção e se ainda é nova, e
  # quanto do pool e de cada pacote o jogador já tem.
  def show
    cards = current_user.collection_cards.order(:obtained_at, :card_id).pluck(:card_id, :quantity, :obtained_at, :seen_at)
    data = cards.map { |card_id, quantity, obtained_at, seen_at| { card_id:, quantity:, obtained_at:, new: seen_at.nil? } }
    progress = Collections::Progress.new(current_user)
    render json: { data:, meta: { total: progress.total, packs: progress.packs } }
  end

  # POST /api/collection/seen: { card_ids } marca essas cartas como vistas (GXP-42); sem a
  # lista, marca todas.
  def seen
    cards = current_user.collection_cards.where(seen_at: nil)
    if params.key?(:card_ids)
      ids = params[:card_ids]
      cards = cards.where(card_id: ids.is_a?(Array) ? ids.first(MAX_SEEN).filter_map { |id| integer_param(id) } : [])
    end
    cards.update_all(seen_at: Time.current)
    head :no_content
  end
end
