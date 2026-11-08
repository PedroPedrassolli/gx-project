# Cartas do catálogo: a lista com busca e filtros e o detalhe de uma carta.
class Api::CardsController < Api::BaseController
  FILTERS = %i[q card_type property attribute race monster_type level atk_min atk_max def_min def_max pack sort order].freeze

  # GET /api/cards
  def index
    return unless catalog_stale?

    cards = snapshot.search(params.permit(*FILTERS).to_h.symbolize_keys)
    render json: { data: cards, meta: { total: cards.size, version: snapshot.version } }
  end

  # GET /api/cards/:id
  def show
    card = snapshot.card(params[:id]) or raise ActiveRecord::RecordNotFound
    render json: { data: card } if catalog_stale?
  end
end
