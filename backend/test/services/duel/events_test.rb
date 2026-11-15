require "test_helper"

class Duel::EventsTest < ActiveSupport::TestCase
  # Uma mensagem como a engine manda (o nome "message" já é do Minitest) e a posição de carta (loc_info, 10 bytes).
  def engine_message(type, payload) = Duel::MessageParser::Message.new(type:, payload: payload.b)
  def loc(controller, location, sequence, position) = [ controller, location, sequence, position ].pack("CCL<L<")
  def at(controller, location, sequence, position) = { controller:, location:, sequence:, position: }

  subject { Duel::Events }

  it "lê da engine o que a mesa mostra e ignora o resto" do
    events = subject.from([
      engine_message(40, [ 1 ].pack("C")),
      engine_message(41, [ 0x08 ].pack("S<")),
      engine_message(90, [ 0, 2, 11, 0xA, 12, 0xA ].pack("CL<L<L<L<L<")),
      engine_message(60, [ 7 ].pack("L<") + loc(0, 4, 2, 1)),
      engine_message(62, [ 0 ].pack("L<") + loc(1, 4, 0, 8)),
      engine_message(54, [ 8 ].pack("L<") + loc(0, 8, 1, 10)),
      engine_message(50, [ 7 ].pack("L<") + loc(0, 4, 2, 1) + loc(0, 16, 0, 1) + [ 0x21 ].pack("L<")),
      engine_message(53, [ 7, 0, 4, 2, 1, 8 ].pack("L<CCCCC")),
      engine_message(2, [ 3, 0, 502 ].pack("CCQ<"))
    ])

    assert_equal [
      { type: "turn", team: 1 },
      { type: "phase", phase: 8 },
      { type: "draw", team: 0, codes: [ 11, 12 ] },
      { type: "summon", kind: "normal", code: 7, **at(0, 4, 2, 1) },
      { type: "summon", kind: "special", code: 0, **at(1, 4, 0, 8) },
      { type: "set", code: 8, **at(0, 8, 1, 10) },
      { type: "move", code: 7, from: at(0, 4, 2, 1), to: at(0, 16, 0, 1), reason: 0x21 },
      { type: "position", code: 7, controller: 0, location: 4, sequence: 2, from: 1, to: 8 }
    ], events
  end

  it "lê a corrente, o ataque, os PV e os sorteios" do
    events = subject.from([
      engine_message(70, [ 9 ].pack("L<") + loc(1, 8, 0, 1) + [ 1, 8, 0, 9 << 20, 1 ].pack("CCL<Q<L<")),
      engine_message(75, [ 1 ].pack("C")),
      engine_message(73, [ 1 ].pack("C")),
      engine_message(74, ""),
      engine_message(110, loc(0, 4, 2, 1) + loc(1, 4, 0, 1)),
      engine_message(110, loc(0, 4, 2, 1) + loc(0, 0, 0, 0)),
      engine_message(91, [ 1, 500 ].pack("CL<")),
      engine_message(92, [ 0, 300 ].pack("CL<")),
      engine_message(100, [ 0, 800 ].pack("CL<")),
      engine_message(31, [ 1, 1, 9, 0, 2, 0 ].pack("CL<L<CCL<")),
      engine_message(130, [ 0, 2, 1, 0 ].pack("CCCC")),
      engine_message(131, [ 1, 1, 4 ].pack("CCC")),
      engine_message(133, [ 2 + (1 << 2) ].pack("C")),
      engine_message(5, [ 1, 0 ].pack("CC"))
    ])

    assert_equal [
      { type: "chain", code: 9, **at(1, 8, 0, 1), description: 9 << 20, link: 1 },
      { type: "chain_negated", link: 1 },
      { type: "chain_solved", link: 1 },
      { type: "chain_end" },
      { type: "attack", attacker: at(0, 4, 2, 1), target: at(1, 4, 0, 1) },
      { type: "attack", attacker: at(0, 4, 2, 1), target: nil },
      { type: "lp", kind: "damage", team: 1, amount: 500 },
      { type: "lp", kind: "recover", team: 0, amount: 300 },
      { type: "lp", kind: "cost", team: 0, amount: 800 },
      { type: "reveal", team: 1, cards: [ { code: 9, controller: 0, location: 2, sequence: 0 } ] },
      { type: "coin", team: 0, results: [ 1, 0 ] },
      { type: "dice", team: 1, results: [ 4 ] },
      { type: "hands", hands: [ 2, 1 ] },
      { type: "win", player: 1, reason: 0 }
    ], events
  end

  it "esconde de cada lado o que ele não vê, como a mesa" do
    draw = { type: "draw", team: 0, codes: [ 11, 12 ] }
    assert_equal draw, subject.mask(draw, 0)
    assert_equal({ type: "draw", team: 0, count: 2 }, subject.mask(draw, 1))

    set = { type: "set", code: 8, **at(0, 8, 1, 10) }
    assert_equal 8, subject.mask(set, 0)[:code]
    assert_equal 0, subject.mask(set, 1)[:code]

    move = ->(from, to) { subject.mask({ type: "move", code: 7, from:, to:, reason: 0 }, 1)[:code] }
    assert_equal 7, move.call(at(0, 2, 0, 0), at(0, 16, 0, 1)), "da mão para o cemitério: à vista"
    assert_equal 7, move.call(at(0, 4, 2, 1), at(0, 2, 0, 0)), "do campo, com a face para cima, para a mão"
    assert_equal 0, move.call(at(0, 1, 0, 0), at(0, 2, 0, 0)), "do deck para a mão"
    assert_equal 0, move.call(at(0, 4, 2, 8), at(0, 2, 0, 0)), "virada no campo, para a mão"
    assert_equal 0, move.call(at(0, 2, 0, 0), at(0, 32, 0, 8)), "banida com a face para baixo"

    position = ->(from, to) { subject.mask({ type: "position", code: 7, controller: 0, location: 4, sequence: 2, from:, to: }, 1)[:code] }
    assert_equal 7, position.call(8, 1), "virou para cima"
    assert_equal 0, position.call(8, 2), "continua virada"
  end
end
