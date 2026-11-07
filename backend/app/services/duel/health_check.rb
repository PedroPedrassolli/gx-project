module Duel
  # Refaz do zero, pelo replay, um duelo inteiro gravado (dois bots, semente e decks
  # fixos): confere que a engine, os scripts e os dados das cartas estão no lugar e mede
  # quanto custa reconstruir um duelo. Usado pelo /up/engine e pelo monitor.
  #
  # Depois de atualizar a engine ou os scripts, grave de novo: bin/rails duel:record_health_check
  class HealthCheck
    RECORDING = Rails.root.join("app/services/duel/health_check_duel.json")

    def self.recording
      @recording ||= JSON.parse(File.read(RECORDING), symbolize_names: true)
    end

    def self.run
      duel = recording
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      engine = Engine.new(seed: duel[:seed], decks: duel[:decks]).start
      winner = winner_of(replay(engine, duel[:responses].map { |hex| [ hex ].pack("H*") }))
      {
        # Resposta que não vale mais faz o duelo desviar: o vencedor deixa de bater.
        ok: engine.errors.empty? && winner == duel[:winner],
        responses: duel[:responses].size,
        winner:,
        ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round(1)
      }
    rescue Engine::Error => error
      { ok: false, error: error.message }
    ensure
      engine&.close
    end

    def self.replay(engine, responses)
      messages = []
      responses.each do |response|
        messages.concat(engine.advance)
        engine.respond(response)
      end
      messages.concat(engine.advance)
    end

    def self.winner_of(messages)
      message = messages.find { |item| item.type == MessageParser::WIN }
      message && MessageParser.win(message)[:player]
    end

    private_class_method :replay, :winner_of
  end
end
