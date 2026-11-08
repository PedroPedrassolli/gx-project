# Pacotes da loja, na ordem do jogo, com a regra de disponibilidade.
class Api::PacksController < Api::BaseController
  # GET /api/packs
  def index
    render json: { data: snapshot.packs, meta: { version: snapshot.version } } if catalog_stale?
  end
end
