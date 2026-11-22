# Cartas do catálogo: a lista com busca e filtros e o detalhe de uma carta.
class Api::CardsController < Api::BaseController
  FILTERS = %i[q card_type property attribute race monster_type level atk_min atk_max def_min def_max pack sort order].freeze

  # GET /api/cards
  def index
    return unless catalog_stale?

    # Cada filtro vai até 100 caracteres: nenhum nome de carta passa disso, e um texto
    # gigante só gastaria CPU (a busca compara com as 3.500 cartas).
    filters = params.permit(*FILTERS).to_h.symbolize_keys.transform_values { |value| value.to_s[0, 100] }
    cards = snapshot.search(filters)
    render json: { data: cards, meta: { total: cards.size, version: snapshot.version } }
  end

  # GET /api/cards/details: o detalhe de todas as cartas, pelo id, sem o que a lista já tem
  # (GXP-121). O front baixa em segundo plano, e o texto de qualquer carta aparece na hora.
  def details
    render json: { data: snapshot.details, meta: { version: snapshot.version } } if catalog_stale?
  end

  # GET /api/cards/:id
  def show
    card = snapshot.card(params[:id]) or raise ActiveRecord::RecordNotFound
    render json: { data: card } if catalog_stale?
  end
end
