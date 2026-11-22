require "test_helper"

# O robô que escolhe ao acaso: os duelos inteiros (robot_duel_test e bot_duel_test) passam
# pela maior parte dele; aqui ficam as perguntas raras, com um "acaso" que não sorteia.
class Bots::RandomPlayerTest < ActiveSupport::TestCase
  def robot(value = 0.1) = Bots::RandomPlayer.new(FixedRandom.new(value), [ 46986414 ])

  it "na batalha, sem monstro para atacar, ativa um efeito" do
    _(robot.choose({ type: "select_battlecmd", activatable: [ {} ], attackable: [], to_m2: true, to_ep: true })).must_equal({ command: "activate", index: 0 })
  end

  it "soma até o valor exato ou até passar dele, nas duas regras" do
    exact = { type: "select_sum", select_max: true, acc: 7, min: 1, max: 3, must: [], cards: [ { sum: 3 }, { sum: 4 }, { sum: 5 | (2 << 16) } ] }
    over = { type: "select_sum", select_max: false, acc: 6, min: 1, max: 3, must: [ { sum: 2 } ], cards: [ { sum: 1 | (5 << 16) }, { sum: 4 } ] }

    _(robot.choose(exact)).must_equal({ indexes: [ 0, 1 ] })
    _(robot.choose(over)).must_equal({ indexes: [ 0 ] })
    _ { robot.choose(exact.merge(acc: 50)) }.must_raise RuntimeError
  end

  it "uma carta por vez: tira uma escolhida ou conclui quando não sobra nada" do
    prompt = { type: "select_unselect_card", finishable: false, selectable: [], unselectable: [ {}, {} ] }

    _(robot.choose(prompt)).must_equal({ index: 0 })
    _(robot.choose(prompt.merge(unselectable: []))).must_equal({ index: -1 })
  end

  it "escolhe uma zona livre, dos dois lados" do
    all_but_one = 0xFFFF_FFFF & ~(1 << (16 + 8 + 2))

    _(robot.choose({ type: "select_disfield", player: 0, count: 1, flag: all_but_one })).must_equal({ places: [ 1, 0x08, 2 ] })
  end

  it "reparte os marcadores sem passar do que cada carta tem" do
    _(robot.choose({ type: "select_counter", count: 3, cards: [ { counters: 1 }, { counters: 5 } ] })).must_equal({ counts: [ 1, 2 ] })
  end

  it "às vezes muda a ordem das cartas" do
    _(robot(0.9).choose({ type: "sort_card", cards: [ {}, {} ] })[:order].sort).must_equal [ 0, 1 ]
    _(robot(0.1).choose({ type: "sort_chain", cards: [ {}, {} ] })).must_equal({})
  end

  it "declara tipo, atributo e carta entre os que valem" do
    player = robot

    _(player.choose({ type: "announce_race", count: 1, available: 0b110 })).must_equal({ mask: 0b10 })
    _(player.choose({ type: "announce_attrib", count: 2, available: 0b1010 })).must_equal({ mask: 0b1010 })
    _(player.choose({ type: "announce_card", opcodes: [] })).must_equal({ code: 46986414 })
    _(player.seen).must_equal({ announce_race: 1, announce_attrib: 1, announce_card: 1 })
  end
end
