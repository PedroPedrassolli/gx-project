require "test_helper"

# Teste de contrato da engine: um duelo inteiro entre dois bots, com semente e decks
# fixos, termina sempre do mesmo jeito. Se a engine ou os scripts mudarem de
# comportamento (ex.: numa atualização), este teste avisa.
class Duel::BotDuelTest < ActiveSupport::TestCase
  # Monstros Normais e de efeito, magias e armadilhas clássicas. A ordem é a do deck
  # (a engine não embaralha no começo); o time 1 usa a mesma lista girada.
  DECK = [ 70781052, 91152256, 69140098, 14898066, 97590747, 11091375, 15025844, 13039848, 43096270, 69247929,
           12493482, 5053103, 49881766, 89631139, 46986414, 26202165, 54652250, 71413901, 83011277, 74131780,
           53129443, 5318639, 72302403, 40619825, 66788016, 97169186, 71044499, 70828912, 14087893, 70368879,
           26412047, 4206964, 56120475, 62279055, 60082869, 12607053, 14315573, 97077563, 83555666, 44095762 ].freeze

  let(:match) { Duel::BotMatch.new(seed: [ 5, 6, 7, 8 ], decks: [ { main: DECK }, { main: DECK.rotate(17) } ]) }

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
end
