namespace :duel do
  desc "Grava de novo o duelo do /up/engine (rode depois de atualizar a engine ou os scripts)"
  task record_health_check: :environment do
    # Os bots ficam nos testes: só este comando de desenvolvimento usa eles.
    Rails.root.glob("test/support/duel/*.rb").each { |file| require file }

    duel = Duel::HealthCheck.recording.slice(:seed, :decks)
    result = Duel::BotMatch.new(**duel).play
    responses = result.responses.map { |response| response.unpack1("H*") }
    recording = duel.merge(winner: result.winner, turns: result.turns, responses:)
    File.write(Duel::HealthCheck::RECORDING, JSON.pretty_generate(recording) + "\n")
    puts "Duelo gravado: #{responses.size} respostas, vitória do time #{result.winner} no turno #{result.turns}."
  end

  desc "Mede aqui o mesmo que o /up/engine: ação fria e quente, N vezes (padrão: 200)"
  task :benchmark, [ :calls ] => :environment do |_task, args|
    results = Array.new(Integer(args[:calls] || 200)) { Duel::HealthCheck.run }
    percentile = ->(values, p) { values.sort[(values.size * p / 100.0).ceil - 1] }
    { cold_ms: "Ação fria (duelo refeito do zero)", warm_ms: "Ação quente (engine no cache)" }.each do |key, label|
      values = results.map { |result| result.fetch(key) }
      puts format("%s: 1ª %.2f ms, p50 %.2f ms, p95 %.2f ms, máximo %.2f ms",
                  label, values.first, percentile.call(values, 50), percentile.call(values, 95), values.max)
    end
  end
end
