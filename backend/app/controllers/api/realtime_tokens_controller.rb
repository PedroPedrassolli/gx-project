# Token do tempo real (ADR 0002): um pedido de token assinado com a chave do Ably, que o
# navegador troca por um token direto no Ably. O token só deixa assinar o canal do próprio
# jogador, e a chave nunca sai do servidor.
class Api::RealtimeTokensController < Api::BaseController
  before_action :require_authentication

  # POST /api/realtime/token
  def create
    key = ENV["ABLY_API_KEY"]
    # Sem a chave (desenvolvimento e CI) não há tempo real: o front consulta a API a cada 2 s.
    return render_error(:service_unavailable, "O tempo real está desligado.") if key.blank?

    render json: { data: Realtime::TokenRequest.new(key).for_user(current_user.id) }
  end
end
