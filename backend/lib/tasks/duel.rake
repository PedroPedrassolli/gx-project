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
end
