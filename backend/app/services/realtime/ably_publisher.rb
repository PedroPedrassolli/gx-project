require "net/http"

module Realtime
  # Manda os eventos pelo REST do Ably: um POST por evento, no canal do jogador. Para o
  # plano, cada evento conta 2 mensagens: a publicada e a entregue a quem assina.
  class AblyPublisher
    class Error < StandardError; end

    HOST = "main.realtime.ably.net".freeze

    # key: a chave do Ably, "app.chave:segredo". Fica só no painel da Vercel.
    def initialize(key)
      @key_name, @secret = key.split(":", 2)
    end

    def publish(user_id:, event:, data:)
      request = Net::HTTP::Post.new("/channels/#{ERB::Util.url_encode(Publisher.channel_for(user_id))}/messages",
                                    "Content-Type" => "application/json")
      request.basic_auth(@key_name, @secret)
      request.body = JSON.generate(name: event, data:)
      response = Net::HTTP.start(HOST, 443, use_ssl: true, open_timeout: 2, read_timeout: 5) { |http| http.request(request) }
      raise Error, "o Ably respondeu #{response.code}" unless response.is_a?(Net::HTTPSuccess)
    end
  end
end
