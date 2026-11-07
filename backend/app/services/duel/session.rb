module Duel
  # Um duelo montado com o que fica no banco: semente, decks e as respostas dadas até agora.
  # A engine não salva o duelo, então o estado é essa lista, e cada ação refaz o duelo pelo
  # replay (docs/adr/0001-engine.md). Para não refazer à toa, a engine viva fica no cache da
  # instância; se o cache não tem o duelo exatamente no mesmo ponto do banco (outra
  # instância avançou, reinício, saiu do cache), o duelo é refeito. Mesmo resultado, só
  # mais lento.
  class Session
    class InvalidResponse < StandardError; end

    # Cerca de 2 MB por duelo no meio do jogo: 32 duelos ocupam uns 70 MB.
    CACHE = EngineCache.new(32)

    attr_reader :responses

    def initialize(id:, seed:, decks:, responses: [], cache: CACHE)
      @id = id
      @seed = seed
      @decks = decks
      @responses = responses.dup
      @cache = cache
      @finished = false
    end

    # Duelo novo: mensagens do começo até a primeira pergunta.
    def start
      raise ArgumentError, "o duelo já começou" if @responses.any?

      engine = Engine.new(seed: @seed, decks: @decks).start
      keep(engine, engine.advance)
    end

    # Aplica a resposta à pergunta atual e devolve as mensagens até a próxima pergunta, ou
    # até o fim do duelo. Se algo falhar no meio, a engine não volta para o cache (o GC a
    # libera) e a próxima ação refaz o duelo.
    def respond(response)
      engine = @cache.take(@id, version) || rebuild
      engine.respond(response)
      messages = engine.advance
      if messages.first&.type == MessageParser::RETRY
        # A engine recusou: o duelo fica na mesma pergunta, igualzinho, e a resposta não
        # entra no histórico.
        @cache.put(@id, version, engine)
        raise InvalidResponse, "a engine recusou a resposta"
      end

      @responses << response
      keep(engine, messages)
    end

    def finished? = @finished

    private

    # Hash das respostas, com o tamanho de cada uma na frente (assim ["ab", "c"] e
    # ["a", "bc"] não dão o mesmo hash).
    def version
      Digest::SHA256.digest(@responses.map { |response| [ response.bytesize ].pack("L<") + response }.join)
    end

    def rebuild
      engine = Engine.new(seed: @seed, decks: @decks).start
      @responses.each do |response|
        engine.advance
        engine.respond(response)
      end
      engine.advance
      engine
    end

    # Guarda a engine para a próxima ação, menos quando o duelo acabou. A engine às vezes
    # segue processando depois do MSG_WIN; para o jogo, o duelo termina ali.
    def keep(engine, messages)
      win = messages.index { |message| message.type == MessageParser::WIN }
      @finished = !win.nil?
      @finished ? engine.close : @cache.put(@id, version, engine)
      win ? messages[..win] : messages
    end
  end
end
