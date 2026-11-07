module Realtime
  # Pedido de token assinado, no formato do Ably ("REST API Token Request Spec"). O Rails
  # assina com a chave e entrega ao navegador, que troca o pedido por um token direto no
  # Ably: a chave nunca sai do servidor. O token só deixa assinar o canal do próprio
  # jogador e vale 1 hora.
  class TokenRequest
    TTL_MS = 60 * 60 * 1000

    def initialize(key)
      @key_name, @secret = key.split(":", 2)
    end

    # O mac é o HMAC-SHA256, em base64, dos campos nesta ordem, cada um seguido de "\n".
    # A capability vai em JSON sem espaços, que é a forma que o Ably assina.
    def for_user(user_id, timestamp: (Time.now.to_r * 1000).to_i, nonce: SecureRandom.hex(16))
      capability = JSON.generate(Publisher.channel_for(user_id) => [ "subscribe" ])
      client_id = user_id.to_s
      text = [ @key_name, TTL_MS, capability, client_id, timestamp, nonce ].map { |field| "#{field}\n" }.join
      mac = Base64.strict_encode64(OpenSSL::HMAC.digest("SHA256", @secret, text))
      { keyName: @key_name, ttl: TTL_MS, capability:, clientId: client_id, timestamp:, nonce:, mac: }
    end
  end
end
