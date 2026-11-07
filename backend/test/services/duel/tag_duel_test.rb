require "test_helper"

# Teste de contrato do Tag: dois duelistas por lado, na ordem A1 → B1 → A2 → B2. O campo e
# o PV são da dupla; mão e deck são de cada duelista.
class Duel::TagDuelTest < ActiveSupport::TestCase
  # Um monstro Normal diferente por duelista, para saber de quem é cada compra:
  # Mokey Mokey, Luster Dragon, Petit Moth e Gene-Warped Warwolf.
  A1, B1, A2, B2 = 27288416, 11091375, 58192742, 69247929
  NAMES = { A1 => :a1, B1 => :b1, A2 => :a2, B2 => :b2 }.freeze

  let(:decks) { [ A1, B1, A2, B2 ].map { |code| { main: [ code ] * 40 } } }
  let(:match) { Duel::BotMatch.new(seed: [ 1, 2, 3, 4 ], decks:) }

  subject { match.play }

  it "cada turno é de um duelista, na ordem A1 → B1 → A2 → B2 → A1" do
    turns = subject.draws.select { |turn, _, _| turn.positive? }.map { |turn, side, cards| [ turn, side, NAMES[cards.first] ] }
    assert_equal [ [ 1, 0, :a1 ], [ 2, 1, :b1 ], [ 3, 0, :a2 ], [ 4, 1, :b2 ], [ 5, 0, :a1 ] ], turns
  end

  it "termina sempre igual: o lado 1 vence por PV no turno 5, sem erro de script" do
    assert_equal [ 1, 1, 5, [] ], [ subject.winner, subject.reason, subject.turns, subject.errors ]
  end

  it "refazer pelo replay dá exatamente as mesmas mensagens" do
    assert_equal subject.digest, match.replay(subject.responses)
  end
end
