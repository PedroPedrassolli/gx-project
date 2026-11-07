require "test_helper"

# Teste de contrato da engine: um duelo inteiro entre dois bots, com semente e decks
# fixos, termina sempre do mesmo jeito. Se a engine ou os scripts mudarem de
# comportamento (ex.: numa atualização), este teste avisa.
class Duel::BotDuelTest < ActiveSupport::TestCase
  # O duelo gravado do /up/engine (app/services/duel/health_check_duel.json): monstros
  # Normais e de efeito, magias e armadilhas clássicas, numa ordem fixa (a engine não
  # embaralha no começo); o time 1 usa a mesma lista girada.
  let(:recording) { Duel::HealthCheck.recording }
  let(:match) { Duel::BotMatch.new(seed: recording[:seed], decks: recording[:decks]) }

  subject { match.play }

  it "termina sempre igual: o time 1 vence por PV no turno 20, depois de 403 respostas" do
    assert_equal [ 1, 1, 20, 403 ], [ subject.winner, subject.reason, subject.turns, subject.responses.size ]
  end

  it "não registra erro de script" do
    assert_empty subject.errors
  end

  it "refazer pelo replay dá exatamente as mesmas mensagens" do
    assert_equal subject.digest, match.replay(subject.responses)
  end

  it "bate com a gravação do /up/engine (se mudou de propósito, rode bin/rails duel:record_health_check)" do
    assert_equal recording[:responses], subject.responses.map { |response| response.unpack1("H*") }
  end
end
