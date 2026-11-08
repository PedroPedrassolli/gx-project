# Coleção do jogador logado (escopo 3.2).
class Api::CollectionsController < Api::BaseController
  before_action :require_authentication

  # GET /api/collection: as cartas, com quantidade e data de obtenção, e quanto do pool e
  # de cada pacote o jogador já tem.
  def show
    cards = current_user.collection_cards.order(:obtained_at, :card_id).select(:card_id, :quantity, :obtained_at)
    progress = Collections::Progress.new(current_user)
    render json: { data: cards.map { |row| row.as_json(except: :id) }, meta: { total: progress.total, packs: progress.packs } }
  end
end
