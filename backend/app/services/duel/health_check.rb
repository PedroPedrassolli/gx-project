module Duel
  # Refaz, pela Duel::Session, um duelo inteiro gravado (dois bots, semente e decks fixos):
  # confere que a engine, os scripts e os dados das cartas estão no lugar e mede as duas
  # situações de uma ação no servidor:
  # - fria: o duelo não está no cache da instância e é refeito do zero pelo replay;
  # - quente: a engine da ação anterior ficou no cache e só a resposta nova é processada.
  # Usado pelo /up/engine, pelo monitor e pelo workflow "Medição da engine".
  #
  # Depois de atualizar a engine ou os scripts, grave de novo: bin/rails duel:record_health_check
  class HealthCheck
    RECORDING = Rails.root.join("app/services/duel/health_check_duel.json")

    def self.recording
      @recording ||= JSON.parse(File.read(RECORDING), symbolize_names: true)
    end

    def self.run
      duel = recording
      responses = duel[:responses].map { |hex| [ hex ].pack("H*") }
      id = "health-check-#{SecureRandom.uuid}"
      # Fria: refaz as primeiras respostas e aplica a penúltima.
      _, cold_ms = measure { session(duel, id, responses[0...-2]).respond(responses[-2]) }
      # Quente: a engine ficou no cache; a última resposta termina o duelo.
      messages, warm_ms = measure { session(duel, id, responses[0...-1]).respond(responses[-1]) }
      winner = winner_of(messages)
      # Resposta que não vale mais faz o duelo desviar: o vencedor deixa de bater.
      { ok: winner == duel[:winner], responses: responses.size, winner:, cold_ms:, warm_ms: }
    rescue Engine::Error, Session::InvalidResponse => error
      { ok: false, error: error.message }
    end

    def self.session(duel, id, responses)
      Session.new(id:, seed: duel[:seed], decks: duel[:decks], responses:)
    end

    def self.measure
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = yield
      [ result, ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round(2) ]
    end

    def self.winner_of(messages)
      message = messages.find { |item| item.type == MessageParser::WIN }
      message && MessageParser.win(message)[:player]
    end

    private_class_method :session, :measure, :winner_of
  end
end
