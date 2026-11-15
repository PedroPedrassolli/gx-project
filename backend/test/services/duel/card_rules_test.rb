require "test_helper"

# Regras das cartas conferidas na engine, com o campo montado à mão (DuelPuzzle). Começou
# com a dúvida de uma magia equipada num monstro baixado (GXP-77): a regra é que equipamento
# só vai para monstro com a face para cima, e algumas magias miram, sim, o monstro virado.
class Duel::CardRulesTest < ActiveSupport::TestCase
  AXE_OF_DESPAIR = 40_619_825 # Equipamento: +1000 de ATK
  BOOK_OF_TAIYOU = 38_699_854 # Mira 1 monstro virado para baixo e o vira para cima
  DARK_MAGICIAN = 46_986_414
  BLUE_EYES = 89_631_139
  HAND = Duel::Query::HAND
  MZONE = Duel::Query::MONSTERS
  UP = DuelPuzzle::FACE_UP_ATTACK
  DOWN = DuelPuzzle::FACE_DOWN_DEFENSE

  before { Duel::Engine.any_instance.expects(:record_error).never }

  # Em cada lado, um monstro baixado na zona 0 e outro com a face para cima na zona 1.
  def both_positions(card)
    [ [ 0, card, HAND, 0, DOWN ], [ 0, DARK_MAGICIAN, MZONE, 0, DOWN ], [ 0, DARK_MAGICIAN, MZONE, 1, UP ],
      [ 1, BLUE_EYES, MZONE, 0, DOWN ], [ 1, BLUE_EYES, MZONE, 1, UP ] ]
  end

  # Ativa a carta da mão na fase principal e devolve a pergunta seguinte (a dos alvos).
  def activate(puzzle, code)
    idle = puzzle.next_prompt
    assert_equal :select_idlecmd, idle[:type]
    index = idle[:activatable].index { |card| card[:code] == code }
    assert index, "a carta #{code} devia aparecer para ativar"
    puzzle.choose(idle, command: "activate", index:)
    puzzle.next_prompt
  end

  def places(prompt) = prompt[:cards].map { |card| card.values_at(:controller, :sequence) }.sort

  it "equipamento só vai para monstro com a face para cima" do
    puzzle = DuelPuzzle.new(both_positions(AXE_OF_DESPAIR)).start
    targets = activate(puzzle, AXE_OF_DESPAIR)

    assert_equal :select_card, targets[:type]
    assert_equal [ [ 0, 1 ], [ 1, 1 ] ], places(targets)
    puzzle.choose(targets, indexes: [ targets[:cards].index { |card| card[:controller].zero? } ])
    puzzle.next_prompt
    assert_equal 3500, puzzle.query_location(0, MZONE)[1][:atk]
  end

  it "sem monstro com a face para cima, o equipamento só pode ser baixado" do
    puzzle = DuelPuzzle.new([ [ 0, AXE_OF_DESPAIR, HAND, 0, DOWN ], [ 0, DARK_MAGICIAN, MZONE, 0, DOWN ],
                              [ 1, BLUE_EYES, MZONE, 0, DOWN ] ]).start
    idle = puzzle.next_prompt

    assert_not idle[:activatable].any? { |card| card[:code] == AXE_OF_DESPAIR }
    assert idle[:ssetable].any? { |card| card[:code] == AXE_OF_DESPAIR }
  end

  it "o Book of Taiyou mira o monstro virado para baixo" do
    puzzle = DuelPuzzle.new(both_positions(BOOK_OF_TAIYOU)).start
    targets = activate(puzzle, BOOK_OF_TAIYOU)

    assert_equal [ [ 0, 0 ], [ 1, 0 ] ], places(targets)
  end
end
