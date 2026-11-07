module Duel
  # Duelo curto e sempre igual, para conferir que a engine, os scripts e os dados das
  # cartas estão no lugar. Usado pelo /up/engine (e pelo monitor de disponibilidade).
  class HealthCheck
    SEED = [ 1, 2, 3, 4 ].freeze
    # 20 cartas clássicas (monstros Normais e alguns de efeito), duas vezes.
    DECK = ([ 70781052, 91152256, 69140098, 14898066, 97590747, 11091375, 15025844, 13039848,
              43096270, 69247929, 12493482, 5053103, 49881766, 89631139, 46986414, 26202165,
              54652250, 71413901, 83011277, 74131780 ] * 2).freeze

    def self.run
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      engine = Engine.new(seed: SEED, decks: [ { main: DECK }, { main: DECK.reverse } ]).start
      messages = engine.advance
      first_prompt = MessageParser.prompt_name(messages.last)
      {
        ok: engine.errors.empty? && !first_prompt.nil?,
        first_prompt:,
        messages: messages.size,
        ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round(1)
      }
    rescue Engine::Error => error
      { ok: false, error: error.message }
    ensure
      engine&.close
    end
  end
end
