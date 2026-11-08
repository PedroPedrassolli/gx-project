# Base da API do front: JSON no prefixo /api, no mesmo domínio do site (escopo 5.6).
class Api::BaseController < ApplicationController
  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  private

  def not_found
    render json: { error: { status: 404, message: "Não encontrado." } }, status: :not_found
  end

  # O catálogo é público e muda pouco: a CDN guarda a resposta por 1 hora (e entrega a
  # cópia velha por até 1 dia enquanto busca a nova), e o navegador, por 5 minutos. O ETag
  # muda com a versão dos dados e com os filtros. Devolve true se precisa responder.
  def catalog_stale?
    expires_in 5.minutes, public: true, "s-maxage": 1.hour.to_i, stale_while_revalidate: 1.day.to_i
    stale?(etag: [ snapshot.version, request.query_string ], public: true)
  end

  def snapshot = Catalog::Snapshot.current
end
