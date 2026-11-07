require "test_helper"

# Perguntas montadas byte a byte no formato da engine (playerop.cpp). O duelo completo
# (BotDuelTest) confere as mais comuns com bytes de verdade; aqui entram todas.
class Duel::MessageParserPromptsTest < ActiveSupport::TestCase
  # Pedaços que se repetem: carta com sequência de 4 ou de 1 byte, loc_info e lista.
  CARD = ->(code) { [ code, 0, 2, 1 ].pack("L<CCL<") }
  SHORT_CARD = ->(code) { [ code, 0, 4, 1 ].pack("L<CCC") }
  LOCATED = ->(code) { [ code, 1, 4, 0, 1 ].pack("L<CCL<L<") }
  LIST = ->(*items) { [ items.size ].pack("L<") + items.join }
  IN_HAND = ->(code) { { code:, controller: 0, location: 2, sequence: 1 } }
  ON_FIELD = ->(code) { { code:, controller: 1, location: 4, sequence: 0, position: 1 } }

  # tipo => [número da mensagem, bytes depois do jogador, campos esperados]
  CASES = {
    select_idlecmd: [ 11, LIST[CARD[1]] + LIST[CARD[2]] + LIST[SHORT_CARD[3]] + LIST[CARD[4]] + LIST[CARD[5]] +
                          LIST[CARD[6] + [ 10, 0 ].pack("Q<C")] + [ 1, 1, 0 ].pack("CCC"),
                      { summonable: [ IN_HAND[1] ], spsummonable: [ IN_HAND[2] ],
                        repositionable: [ { code: 3, controller: 0, location: 4, sequence: 1 } ],
                        msetable: [ IN_HAND[4] ], ssetable: [ IN_HAND[5] ],
                        activatable: [ { **IN_HAND[6], description: 10, client_mode: 0 } ],
                        to_bp: true, to_ep: true, can_shuffle: false } ],
    select_battlecmd: [ 10, LIST[CARD[6] + [ 10, 0 ].pack("Q<C")] + LIST[SHORT_CARD[3] + [ 1 ].pack("C")] + [ 0, 1 ].pack("CC"),
                        { activatable: [ { **IN_HAND[6], description: 10, client_mode: 0 } ],
                          attackable: [ { code: 3, controller: 0, location: 4, sequence: 1, direct: true } ],
                          to_m2: false, to_ep: true } ],
    select_card: [ 15, [ 1, 1, 2 ].pack("CL<L<") + LIST[LOCATED[7]],
                   { cancelable: true, min: 1, max: 2, cards: [ ON_FIELD[7] ] } ],
    select_unselect_card: [ 26, [ 0, 1, 1, 1 ].pack("CCL<L<") + LIST[LOCATED[7]] + LIST[LOCATED[8]],
                            { finishable: false, cancelable: true, min: 1, max: 1,
                              selectable: [ ON_FIELD[7] ], unselectable: [ ON_FIELD[8] ] } ],
    select_chain: [ 16, [ 1, 0, 4, 8 ].pack("CCL<L<") + LIST[LOCATED[7] + [ 11, 1 ].pack("Q<C")],
                    { spe_count: 1, forced: false, hint_timing: 4, hint_timing_other: 8,
                      chains: [ { **ON_FIELD[7], description: 11, client_mode: 1 } ] } ],
    select_place: [ 18, [ 1, 0x1f ].pack("CL<"), { count: 1, flag: 31 } ],
    select_tribute: [ 20, [ 0, 2, 2 ].pack("CL<L<") + LIST[CARD[9] + [ 1 ].pack("C")],
                      { cancelable: false, min: 2, max: 2, cards: [ { **IN_HAND[9], release_param: 1 } ] } ],
    select_effectyn: [ 12, [ 55, 0, 4, 1, 1, 7 ].pack("L<CCL<L<Q<"),
                       { code: 55, controller: 0, location: 4, sequence: 1, position: 1, description: 7 } ],
    select_yesno: [ 13, [ 9 ].pack("Q<"), { description: 9 } ],
    select_option: [ 14, [ 2, 5, 6 ].pack("CQ<Q<"), { options: [ 5, 6 ] } ],
    select_position: [ 19, [ 123, 5 ].pack("L<C"), { code: 123, positions: 5 } ],
    select_counter: [ 22, [ 3, 2, 1, 77, 0, 4, 1, 2 ].pack("S<S<L<L<CCCS<"),
                      { counter_type: 3, count: 2,
                        cards: [ { code: 77, controller: 0, location: 4, sequence: 1, counters: 2 } ] } ],
    select_sum: [ 23, [ 0, 5, 1, 2 ].pack("CL<L<L<") + LIST[LOCATED[87] + [ 4 ].pack("L<")] + LIST[LOCATED[88] + [ 3 ].pack("L<")],
                  { select_max: true, acc: 5, min: 1, max: 2, must: [ { **ON_FIELD[87], sum: 4 } ],
                    cards: [ { **ON_FIELD[88], sum: 3 } ] } ],
    select_disfield: [ 24, [ 1, 0xff ].pack("CL<"), { count: 1, flag: 255 } ],
    sort_card: [ 25, [ 1, 42, 0, 1, 3 ].pack("L<L<CL<L<"),
                 { cards: [ { code: 42, controller: 0, location: 1, sequence: 3 } ] } ],
    sort_chain: [ 21, [ 0 ].pack("L<"), { cards: [] } ],
    rock_paper_scissors: [ 132, "".b, {} ],
    announce_race: [ 140, [ 1, 0x30 ].pack("CQ<"), { count: 1, available: 48 } ],
    announce_attrib: [ 141, [ 1, 0x30 ].pack("CL<"), { count: 1, available: 48 } ],
    announce_card: [ 142, [ 1, 99 ].pack("CQ<"), { opcodes: [ 99 ] } ],
    announce_number: [ 143, [ 2, 1, 2 ].pack("CQ<Q<"), { options: [ 1, 2 ] } ]
  }.freeze

  subject { Duel::MessageParser }

  describe ".prompt" do
    CASES.each do |name, (type, fields, expected)|
      it "lê #{name}" do
        message = Duel::MessageParser::Message.new(type:, payload: [ 1 ].pack("C") + fields)
        assert_equal({ type: name, player: 1 }.merge(expected), subject.prompt(message))
      end
    end

    it "devolve nil para mensagem que não é pergunta" do
      assert_nil subject.prompt(Duel::MessageParser::Message.new(type: Duel::MessageParser::WIN, payload: "\x01\x01".b))
    end
  end
end
