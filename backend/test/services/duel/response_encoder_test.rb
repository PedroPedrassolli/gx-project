require "test_helper"

class Duel::ResponseEncoderTest < ActiveSupport::TestCase
  def encode(type, choice) = Duel::ResponseEncoder.encode(type, choice)
  def int(value) = [ value ].pack("l<")

  it "comandos da fase principal e da batalha: o índice nos 16 bits de cima" do
    assert_equal int((2 << 16) | 0), encode(:select_idlecmd, { command: "summon", index: 2 })
    assert_equal int(7), encode(:select_idlecmd, { command: "end" })
    assert_equal int((1 << 16) | 1), encode(:select_battlecmd, { command: "attack", index: "1" })
  end

  it "sim ou não, opção, cadeia e número" do
    assert_equal [ int(1), int(0) ], [ encode(:select_yesno, { yes: true }), encode(:select_effectyn, { yes: "talvez" }) ]
    assert_equal [ int(-1), int(3) ], [ encode(:select_chain, { index: -1 }), encode(:select_option, { index: 3 }) ]
  end

  it "seleção de cartas: tipo 0, quantidade e índices; desistir é -1" do
    assert_equal [ 0, 2, 4, 1 ].pack("l<L<L<L<"), encode(:select_card, { indexes: [ 4, 1 ] })
    assert_equal int(-1), encode(:select_tribute, { cancel: true })
    assert_equal [ 1, 3 ].pack("l<l<"), encode(:select_unselect_card, { index: 3 })
    assert_equal int(-1), encode(:select_unselect_card, { index: -1 })
  end

  it "zonas, posição, contadores, ordem, anúncios e pedra, papel e tesoura" do
    assert_equal [ 0, 4, 2 ].pack("C*"), encode(:select_place, { places: [ 0, 4, 2 ] })
    assert_equal int(0x8), encode(:select_position, { position: 0x8 })
    assert_equal [ 1, 0 ].pack("s<s<"), encode(:select_counter, { counts: [ 1, 0 ] })
    assert_equal [ [ -1 ].pack("c"), [ 1, 0 ].pack("C*") ], [ encode(:sort_card, {}), encode(:sort_chain, { order: [ 1, 0 ] }) ]
    assert_equal [ [ 0x20 ].pack("Q<"), [ 0x4 ].pack("L<"), [ 46_986_414 ].pack("L<") ],
                 [ encode(:announce_race, { mask: 0x20 }), encode(:announce_attrib, { mask: 0x4 }), encode(:announce_card, { code: 46_986_414 }) ]
    assert_equal int(2), encode(:rock_paper_scissors, { hand: 2 })
  end

  it "recusa o que não tem a forma da pergunta" do
    [ [ :select_idlecmd, { command: "voar" } ], [ :select_idlecmd, { command: "summon", index: 999 } ],
      [ :select_card, { indexes: [] } ], [ :select_card, { indexes: "1" } ], [ :select_position, { position: 3 } ],
      [ :select_chain, { index: 1.5 } ], [ :select_place, { places: [ 300 ] } ], [ :rock_paper_scissors, { hand: nil } ],
      [ :mensagem_nova, {} ] ].each do |type, choice|
      assert_raises(Duel::ResponseEncoder::InvalidChoice, "#{type} #{choice}") { encode(type, choice) }
    end
  end
end
