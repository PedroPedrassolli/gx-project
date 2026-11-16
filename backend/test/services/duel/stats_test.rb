require "test_helper"

# As contas da Duel::Stats com os eventos escritos à mão (o que a engine manda de verdade está
# em stats_engine_test.rb). Aqui entram os casos que pedem um duelo longo ou uma carta rara.
class Duel::StatsTest < ActiveSupport::TestCase
  HAND = Duel::Events::HAND
  DECK = Duel::Events::DECK
  GRAVE = Duel::Events::GRAVE
  BANISHED = Duel::Events::BANISHED
  MZONE = Duel::Stats::MONSTER_ZONE
  SZONE = Duel::Stats::SPELL_ZONE
  EFFECT = Duel::Stats::EFFECT
  # Cartas de mentira: o código diz o tipo.
  TOON = 10
  TOKEN = 20
  UNION = 30
  QUICK_SPELL = 40
  MONSTER = 50
  TYPES = { TOON => 0x1 | Duel::Stats::TOON, TOKEN => 0x1 | Duel::Stats::TOKEN, UNION => 0x1 | Duel::Stats::UNION,
            QUICK_SPELL => Duel::Stats::SPELL | Duel::Stats::QUICK_PLAY }.freeze

  let(:stats) { Duel::Stats.new(types: ->(code) { TYPES.fetch(code, 0x1) }) }

  def at(team, location, sequence = 0, position = 0x1) = { controller: team, location:, sequence:, position: }
  def move(code, from, to, reason = 0) = { type: "move", code:, from:, to:, reason: }
  def damage(team, amount) = { type: "lp", kind: "damage", team:, amount: }
  def battle(attacker, target = nil) = { type: "battle", attacker:, attack: 2500, target:, target_attack: 0 }
  def turn(team) = { type: "turn", team: }
  def link(team, code = MONSTER) = [ { type: "chain", code:, link: 1, **at(team, MZONE) }, { type: "chain_solving", link: 1 } ]

  it "ataque direto de Toon, golpe final e dano exato" do
    stats.apply([ move(TOON, at(0, HAND), at(0, MZONE)), battle(at(0, MZONE)), damage(1, 8000) ])

    assert_equal [ 8000, 8000, true, TOON ], stats.team(0).values_at("direct_damage", "toon_direct_damage", "exact_finish", "finisher")
    assert_equal [ false, nil ], stats.team(1).values_at("exact_finish", "finisher")
  end

  it "o golpe que passa do PV não é exato, e o ataque a um monstro não é direto" do
    stats.apply([ move(MONSTER, at(0, HAND), at(0, MZONE)), battle(at(0, MZONE), at(1, MZONE)), damage(1, 9000) ])

    assert_equal [ false, MONSTER, 9000, nil ], stats.team(0).values_at("exact_finish", "finisher", "max_attack_damage", "direct_damage")
  end

  it "o dano de efeito depois de uma corrente não é de batalha, e não tem carta do golpe final" do
    stats.apply([ battle(at(0, MZONE)), *link(0), damage(1, 8000) ])

    assert_equal [ 8000, nil, true, nil ], stats.team(0).values_at("effect_damage", "battle_damage", "exact_finish", "finisher")
  end

  it "virada, o maior dano num turno, PV recuperado e PV acertado direto" do
    stats.apply([ turn(0), damage(0, 3000), damage(0, 500), turn(1), damage(0, 1000), { type: "phase", phase: 8 },
                  { type: "lp", kind: "recover", team: 0, amount: 200 }, { type: "lp", kind: "cost", team: 1, amount: 1000 }, turn(0) ])
    assert_equal [ true, 200, 4500 ], stats.team(0).values_at("reversal", "recovered", "max_lp_deficit")
    assert_equal [ false, 3500, 3000 ], stats.team(1).values_at("reversal", "max_turn_damage", "max_hit")

    stats.update([ Duel::MessageParser::Message.new(type: Duel::Stats::LP_UPDATE, payload: [ 1, 100 ].pack("CL<")) ])
    assert_equal 3600, stats.team(1)["max_lp_deficit"]
  end

  it "cartas do oponente removidas, descartadas do deck e devolvidas para a mão por um efeito" do
    stats.apply([ *link(0), move(1, at(1, MZONE), at(1, BANISHED), EFFECT), move(2, at(1, GRAVE), at(1, BANISHED), EFFECT),
                  move(3, at(0, GRAVE), at(0, BANISHED), EFFECT | Duel::Stats::COST), move(4, at(0, MZONE, 1), at(0, BANISHED), EFFECT),
                  move(5, at(1, DECK), at(1, GRAVE), EFFECT), move(6, at(1, GRAVE), at(1, HAND), EFFECT),
                  move(7, at(0, SZONE), at(0, HAND), EFFECT), { type: "chain_solved", link: 1 }, { type: "chain_end" } ])

    assert_equal [ 2, 1, 1, 2 ], stats.team(0).values_at("banished", "banished_monsters", "deck_discards", "returned")
    assert_equal [ nil, nil ], stats.team(1).values_at("banished", "returned")
  end

  it "fora de corrente, a carta destruída ou removida por efeito é do oponente do dono" do
    stats.apply([ move(1, at(1, SZONE), at(1, GRAVE), EFFECT | Duel::Stats::DESTROY), move(2, at(1, MZONE), at(1, BANISHED), EFFECT),
                  move(3, at(1, GRAVE), at(1, HAND), EFFECT) ])

    assert_equal [ 1, nil, 1, nil ], stats.team(0).values_at("effect_destroyed", "effect_destroyed_monsters", "banished", "returned")
  end

  it "todas as zonas de monstro ocupadas e três cartas iguais; ficha não vale" do
    stats.apply([ MONSTER, MONSTER, MONSTER, 51, 52 ].each_with_index.map { |code, zone| move(code, at(1, HAND), at(1, MZONE, zone)) })
    stats.apply(Array.new(3) { |zone| move(TOKEN, at(0, 0), at(0, MZONE, zone)) })

    assert_equal [ true, true ], stats.team(1).values_at("full_field", "same_three")
    assert_equal [ nil, nil ], stats.team(0).values_at("full_field", "same_three")
  end

  it "invocações: virada, ficha e União; a Fusão revivida não é Invocação-Fusão" do
    special = ->(code) { { type: "summon", kind: "special", code:, **at(0, MZONE) } }
    stats.apply([ { type: "summon", kind: "flip", code: MONSTER, **at(0, MZONE) }, special.call(TOKEN), special.call(UNION) ])

    assert_equal [ 1, 2, 1, 1, nil, [ MONSTER, TOKEN, UNION ] ],
                 stats.team(0).values_at("flip_summons", "special_summons", "tokens", "unions", "fusion_summons", "summoned")
  end

  it "ataque negado e elo negado contam para quem negou, uma vez por elo" do
    stats.update([ Duel::MessageParser::Message.new(type: Duel::Stats::ATTACK_DISABLED, payload: "") ])
    stats.apply([ *link(1), { type: "chain_negated", link: 1 }, { type: "chain_negated", link: 1 }, { type: "chain_negated", link: 9 },
                  { type: "chain_solved", link: 1 }, { type: "chain_solved", link: 9 } ])

    assert_equal [ 1, nil ], [ stats.team(0)["negations"], stats.team(1)["used"] ]
    assert_equal 1, stats.team(1)["negations"]
  end

  it "magia rápida no turno do oponente, e a carta virada para cima que entra na corrente" do
    place = at(0, SZONE, 2, 0x5)
    stats.apply([ turn(1), move(QUICK_SPELL, at(0, HAND), at(0, SZONE, 2, 0xa)),
                  { type: "position", code: QUICK_SPELL, controller: 0, location: SZONE, sequence: 2, from: 0xa, to: 0x5 },
                  { type: "chain", code: QUICK_SPELL, link: 1, **place }, { type: "chain", code: QUICK_SPELL, link: 2, **place } ])

    assert_equal [ 1, 1, 2 ], stats.team(0).values_at("spells", "quick_spells_on_opponent_turn", "max_chain")
  end

  it "a moeda: acerta quem disse o lado que caiu; sem dizer, cara é acerto" do
    stats.apply([ { type: "coin_call", team: 0, call: Duel::Stats::TAILS }, { type: "coin", team: 0, results: [ 0 ] },
                  { type: "coin", team: 0, results: [ 1, 1, 0 ] }, { type: "coin", team: 0, results: [ 1 ] } ])

    assert_equal 3, stats.team(0)["coin_streak"]
  end

  it "o maior ATK é o do monstro virado para cima, e as contas voltam do banco como foram" do
    stats.sample(0, [ nil, { atk: 3000, position: 0x8 }, { atk: 2800, position: 0x1 } ])
    stats.apply([ { type: "position", code: MONSTER, controller: 0, location: MZONE, sequence: 3, from: 0x8, to: 0x1 }, { type: "win", player: 0 } ])
    again = Duel::Stats.new(JSON.parse(stats.to_h.to_json))

    assert_equal 2800, again.team(0)["max_atk"]
    assert_equal stats.to_h, again.to_h
  end
end
