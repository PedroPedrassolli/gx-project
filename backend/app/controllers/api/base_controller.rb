# Base da API do front: JSON no prefixo /api, no mesmo domínio do site (escopo 5.6).
class Api::BaseController < ApplicationController
  include ActionController::Cookies
  include ActionController::RequestForgeryProtection
  include Authentication

  # Todo pedido que muda algo precisa do token CSRF no cabeçalho X-CSRF-Token (ADR 0008).
  protect_from_forgery with: :exception
  # Os parâmetros vêm soltos no JSON, sem a cópia aninhada que o Rails faria.
  wrap_parameters false

  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActionController::InvalidAuthenticityToken, with: :stale_page

  private

  # Erro no formato da API: { error: { status, message, fields } }. fields tem as
  # mensagens de cada campo do formulário, quando houver.
  def render_error(status, message, fields = nil)
    error = { status: Rack::Utils.status_code(status), message:, fields: }.compact
    render json: { error: }, status:
  end

  def not_found = render_error(:not_found, "Não encontrado.")

  def stale_page = render_error(:forbidden, "A página ficou velha. Recarregue e tente de novo.")

  # O catálogo é público e muda pouco: a CDN guarda a resposta por 1 hora (e entrega a
  # cópia velha por até 1 dia enquanto busca a nova), e o navegador, por 5 minutos. O ETag
  # muda com a versão dos dados e com os filtros. Devolve true se precisa responder.
  def catalog_stale?
    expires_in 5.minutes, public: true, "s-maxage": 1.hour.to_i, stale_while_revalidate: 1.day.to_i
    stale?(etag: [ snapshot.version, request.query_string ], public: true)
  end

  def snapshot = Catalog::Snapshot.current
end
