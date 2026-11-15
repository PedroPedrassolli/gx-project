require "test_helper"

class Matches::AutoPlaceTest < ActiveSupport::TestCase
  # O "flag" da engine: bit ligado é zona que não vale (ocupada ou de outro tipo).
  ONLY_MY_MONSTERS = 0xFFFFFFFF & ~0x1F
  ONLY_MY_SPELLS = 0xFFFFFFFF & ~(0x3F << 8)

  def pick(flag, player: 0, count: 1) = Matches::AutoPlace.pick({ type: :select_place, player:, count:, flag: })

  it "escolhe a zona livre do centro para as pontas" do
    assert_equal [ 0, 0x04, 2 ].pack("C*"), pick(ONLY_MY_MONSTERS)
    assert_equal [ 1, 0x04, 1 ].pack("C*"), pick(ONLY_MY_MONSTERS | 0b100, player: 1)
    assert_equal [ 0, 0x08, 2, 0, 0x08, 1 ].pack("C*"), pick(ONLY_MY_SPELLS, count: 2)
  end

  it "usa a zona de campo e o lado do outro quando só elas valem" do
    assert_equal [ 0, 0x08, 5 ].pack("C*"), pick(0xFFFFFFFF & ~(1 << 13))
    assert_equal [ 0, 0x04, 0 ].pack("C*"), pick(0xFFFFFFFF & ~(1 << 16), player: 1)
  end

  it "sem zona livre bastante, deixa a pergunta para o jogador" do
    assert_nil pick(0xFFFFFFFF)
    assert_nil pick(ONLY_MY_MONSTERS | 0b11110, count: 2)
  end
end
