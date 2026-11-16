require "test_helper"

class Economy::ChallengesTest < ActiveSupport::TestCase
  FakeCard = Struct.new(:id, :name, :card_type, :card_attribute, :race, :monster_types, :level, :attack)

  def monster(name: "Monstro", attribute: "DARK", race: "Fiend", types: [ "Effect" ], level: 4, attack: 1_500, id: name.hash)
    FakeCard.new(id, name, "Monster", attribute, race, types, level, attack)
  end

  def spell = FakeCard.new(1, "Magia", "Spell", nil, nil, [], nil, nil)
  def trap = FakeCard.new(2, "Armadilha", "Trap", nil, nil, [], nil, nil)

  # Um deck que não conclui nenhum desafio de deck: monstros de dois atributos, dois tipos,
  # nível 4 e 6, com 1.500 de ATK, de Efeito, mais magia e armadilha, com carta repetida e
  # uma carta da banlist.
  def mixed = [ monster(id: 3), monster(id: 3), monster(name: "Outro", attribute: "LIGHT", race: "Fairy", level: 6, id: 4), spell, trap ]

  # Um duelo vencido em que o jogador fez de tudo um pouco: nenhum "sem isso" vale.
  BUSY = { "damage_taken" => 100, "tributes" => 1, "special_summons" => 1, "normal_summons" => 1 }.freeze

  def facts(counts: {}, **changes)
    Economy::Challenges::Facts.new(won: true, draw: false, turns: 10, opponent_turn: false, win_reason: 1, counts: BUSY.merge(counts),
                                   summoned: [], used: [], finisher: nil, main: mixed, extra: [], restricted: Set[3], **changes)
  end

  def done(**changes) = Economy::Challenges.completed(facts(**changes))

  it "são 104, numerados na ordem do jogo, e 3 ainda não dá para concluir" do
    list = Economy::Challenges::LIST

    assert_equal (1..104).to_a, list.pluck(:number)
    assert_equal [ 25, 38, 39 ], list.reject { |challenge| challenge[:check] }.pluck(:number)
    assert_equal "Acertar a moeda 10 vezes seguidas", Economy::Challenges.label(104)
    assert_equal [ "Empatar um duelo", "Vencer com Exodia", "Vencer com um deck só com monstros do tipo Réptil" ],
                 [ 26, 35, 88 ].map { |number| Economy::Challenges.label(number) }
  end

  it "o duelo comum, com um deck misturado, não conclui nenhum" do
    assert_empty done
  end

  it "1 a 24: chegar ao número conclui, ganhando ou não; um a menos, não" do
    enough = Economy::Challenges::COUNTS.to_h { |name, minimum, _label| [ name, minimum ] }
    almost = enough.transform_values { |minimum| minimum - 1 }

    assert_equal (1..24).to_a, done(won: false, counts: enough)
    assert_empty done(won: false, counts: almost)
    assert_equal [ 104 ], done(won: false, counts: { "coin_streak" => 10 })
  end

  it "26 a 39: o empate e as formas de vencer" do
    assert_equal [ 26 ], done(won: false, draw: true)
    assert_equal [ 27 ], done(counts: { "damage_taken" => 0 })
    assert_equal [ 28, 29 ], done(counts: { "max_turn_damage" => 8_000, "max_hit" => 8_000 })
    assert_equal [ 30 ], done(win_reason: 2)
    assert_equal [ [ 31 ], [ 31, 32 ], [ 31, 32, 33 ] ], [ 7, 5, 3 ].map { |turns| done(turns:) }
    assert_equal [ 34 ], done(opponent_turn: true)
    assert_equal [ [ 35 ], [ 36 ], [ 37 ] ], [ 0x10, 0x11, 0x15 ].map { |win_reason| done(win_reason:) }
    assert_empty done(won: false, turns: 3, opponent_turn: true, win_reason: 0x10, counts: { "damage_taken" => 0 })
  end

  it "40 a 54: cartas invocadas ou usadas, e o golpe final" do
    xyz = Economy::Challenges::XYZ_SERIES
    beasts = Economy::Challenges::SACRED_BEASTS

    assert_equal [ 40 ], done(summoned: xyz)
    assert_empty done(summoned: xyz.first(6))
    assert_equal [ 41 ], done(summoned: [ "VWXYZ-Dragon Catapult Cannon" ])
    assert_equal [ 42, 43, 44, 45 ], done(summoned: beasts)
    assert_equal [ 43 ], done(summoned: [ beasts[1] ])
    assert_equal [ 46, 47, 52, 53 ], done(used: [ "Ojama Delta Hurricane!!", "Huge Revolution", "Dark Scorpion Combination", "Dark Scorpion Retreat" ])
    assert_equal [ 48, 49, 50, 51 ], done(summoned: [ "Perfectly Ultimate Great Moth", "Gate Guardian", "Valkyrion the Magna Warrior", "Dark Sage" ])
    assert_equal [ 54 ], done(finisher: "Skull Servant")
  end

  it "55 a 62: decks sem certos monstros" do
    normal = ->(**options) { monster(types: [ "Normal" ], **options) }

    assert_equal [ 55 ], done(main: [ normal.call(id: 3), normal.call(id: 3), normal.call(level: 6, attribute: "LIGHT", race: "Fairy", id: 3), spell, trap ])
    assert_equal [ 56, 60 ], done(main: [ monster(level: 5, attack: 2_400, id: 3), monster(level: 8, attack: 3_000, attribute: "LIGHT", race: "Dragon", id: 3), spell, spell, trap ])
    assert_equal [ 57, 58, 61, 62 ], done(main: [ monster(level: 1, attack: 0, id: 3), monster(level: 1, attack: nil, attribute: "LIGHT", race: "Fairy", id: 3), spell, spell, trap ])
    levels = (1..12).map { |level| monster(level:, attribute: level.odd? ? "DARK" : "LIGHT", race: level.odd? ? "Fiend" : "Fairy", id: 3) }
    assert_equal [ 59 ], done(main: [ *levels, spell, spell, trap ])
  end

  it "63 a 92: decks em que todo monstro é de um jeito" do
    only = ->(**options) { [ monster(id: 3, **options), monster(id: 3, level: 6, **options), spell, spell, trap ] }

    assert_equal [ 63, 87 ], done(main: only.call(attribute: "LIGHT", race: "Thunder"))
    assert_equal [ 68, 69 ], done(main: only.call(attribute: "WIND", race: "Dragon"))
    assert_equal [ 64, 71, 89 ], done(main: only.call(name: "Horus the Black Flame Dragon LV6"))
    assert_equal [ 64, 71, 90 ], done(main: only.call(name: "Elemental HERO Avian"))
    assert_equal [ 64, 71, 91 ], done(main: only.call(types: %w[Spirit Effect]))
    assert_equal [ 64, 71, 92 ], done(main: only.call(types: %w[Toon Effect]))
  end

  it "93 a 100: o deck inteiro" do
    assert_equal [ 55, 56, 57, 58, 60, 61, 62, 93, 94 ], done(main: [ spell, spell, trap ], restricted: Set[1])
    assert_equal [ 55, 56, 57, 58, 60, 61, 62, 93 ], done(main: [ spell, spell, trap ], extra: [ monster(id: 1) ], restricted: Set[1])
    assert_equal [ 95 ], done(main: mixed - [ trap ])
    assert_equal [ 96 ], done(main: mixed - [ spell ])
    assert_equal [ 95, 96, 97 ], done(main: mixed.first(3))
    assert_equal [ 98 ], done(main: mixed * 12)
    assert_equal [ 99 ], done(restricted: Set[9])
    assert_equal [ 100 ], done(main: mixed.drop(1))
  end

  it "101 a 103: o que o jogador não fez no duelo" do
    assert_equal [ 101, 102, 103 ], done(counts: { "tributes" => 0, "special_summons" => 0, "normal_summons" => 0 })
  end
end
