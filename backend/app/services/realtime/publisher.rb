module Realtime
  # Eventos em tempo real para os jogadores. Cada jogador tem um canal privado,
  # private:user:{id}, que só ele consegue assinar (Realtime::TokenRequest).
  #
  # Com a ABLY_API_KEY (produção, no painel da Vercel), os eventos vão pelo Ably
  # (Realtime::AblyPublisher). Sem a chave (desenvolvimento e CI), ficam na memória
  # (Realtime::MemoryPublisher), onde os testes conferem o que foi mandado. Os dois
  # respondem a publish(user_id:, event:, data:).
  module Publisher
    # Só letras, números, "_" e "-": um "*" no id viraria curinga na permissão do token e
    # abriria o canal de todo mundo.
    def self.channel_for(user_id)
      raise ArgumentError, "id de jogador inválido: #{user_id.inspect}" unless user_id.to_s.match?(/\A[\w-]+\z/)

      "private:user:#{user_id}"
    end

    def self.current
      @current ||= build(ENV["ABLY_API_KEY"])
    end

    def self.build(key) = key.present? ? AblyPublisher.new(key) : MemoryPublisher.new
  end
end
