# Banlists com o status de cada carta.
class Api::BanlistsController < Api::BaseController
  # GET /api/banlists
  def index
    render json: { data: snapshot.banlists, meta: { version: snapshot.version } } if catalog_stale?
  end
end
