require "test_helper"

class Economy::BonusCalculatorTest < ActiveSupport::TestCase
  # Um duelo comum, vencido na engine: 6 turnos, nível 1 contra nível 12, 3.000 PV e 20 cartas
  # no deck no fim, no próprio turno. No duelo houve magia, armadilha, Invocação-Especial,
  # dano de batalha e de efeito e dano sofrido, para nenhum bônus de "sem isso" aparecer.
  PLAIN = { "spells" => 1, "traps" => 1, "special_summons" => 1, "battle_damage" => 7000, "effect_damage" => 1000, "damage_taken" => 5000 }.freeze

  def stats(duel: {}, **changes)
    { result: :win, turns: 6, level: 1, opponent_level: 12, challenges: 0, engine_win: true, win_reason: 1, lp: 3_000, deck: 20,
      opponent_turn: false, duel: PLAIN.merge(duel) }.merge(changes)
  end

  # Sem os prêmios do GX Project, que têm o próprio teste: o resto são os valores do jogo.
  PRIZES = %w[prize win_prize].freeze

  def dp(**changes) = Economy::BonusCalculator.lines(stats(**changes)).to_h { |line| [ line[:key], line[:dp] ] }.except(*PRIZES)
  def labels(**changes) = Economy::BonusCalculator.lines(stats(**changes)).pluck(:label)

  it "os prêmios do GX Project: 300 para todo duelo e mais 200 para quem vence, no começo da lista" do
    win = Economy::BonusCalculator.lines(stats)
    assert_equal [ [ "prize", "Prêmio do duelo", 300 ], [ "win_prize", "Prêmio da vitória", 200 ] ], win.first(2).map(&:values)
    assert_equal [ [ "prize", 300 ] ], Economy::BonusCalculator.lines(stats(result: :loss)).first(2).map { |line| line.values_at(:key, :dp) }.first(1)
    assert_not Economy::BonusCalculator.lines(stats(result: :draw)).any? { |line| line[:key] == "win_prize" }
  end

  it "vitória: nível, 2 por turno, vitória em rede e 90 por faixa de nível do oponente" do
    assert_equal({ "level" => 2, "turns" => 12, "network_win" => 50, "duelist" => 180 }, dp)
    assert_includes labels, "Oponente de nível 12"
  end

  it "derrota e empate: o próprio bônus e 1 por turno; 2 por desafio concluído" do
    assert_equal({ "level" => 4, "loss" => 10, "turns" => 6 }, dp(result: :loss, level: 2))
    assert_equal({ "level" => 2, "challenges" => 14, "draw" => 50, "turns" => 6 }, dp(result: :draw, challenges: 7))
  end

  it "as formas de vencer: turnos, PV, deck e as vitórias especiais" do
    assert_equal 10, dp(turns: 5)["quick"]
    assert_equal 20, dp(opponent_turn: true)["opponent_turn"]
    assert_equal 20, dp(win_reason: 2)["no_cards"]
    assert_equal [ 20, 100 ], dp(lp: 50).values_at("low_lp", "very_low_lp")
    assert_equal [ 20, nil ], dp(lp: 999).values_at("low_lp", "very_low_lp")
    assert_equal 100, dp(lp: 20_001)["high_lp"]
    assert_equal 573, dp(lp: 5_730)["konami"]
    assert_equal [ 20, 100 ], dp(deck: 0).values_at("low_deck", "empty_deck")
    assert_equal [ 50, 100 ], [ dp(win_reason: 0x10)["exodia"], dp(win_reason: 0x15)["destiny_board"] ]
  end

  it "as formas de vencer que saem das contas do duelo" do
    assert_equal 20, dp(duel: { "reversal" => true })["reversal"]
    assert_equal 10, dp(duel: { "damage_taken" => 0 })["no_damage"]
    assert_equal [ 20, nil ], [ dp(duel: { "max_lp_deficit" => 5_200 })["lp_deficit"], dp(duel: { "max_lp_deficit" => 4_999 })["lp_deficit"] ]
    assert_equal [ 10, nil ], [ dp(duel: { "exact_finish" => true })["exact"], dp(duel: { "exact_finish" => true }, win_reason: 2)["exact"] ]
    assert_equal [ 10, 30 ], [ dp(duel: { "effect_damage" => 0 })["battle_only"], dp(duel: { "battle_damage" => 0 })["effect_only"] ]
    assert_equal 1, dp(finisher: "Skull Servant")["skull_servant"]
  end

  it "desistência ou tempo não valem as formas de vencer" do
    assert_equal %w[level turns network_win duelist],
                 dp(engine_win: false, lp: 5_730, turns: 3, duel: { "reversal" => true, "damage_taken" => 0 }, finisher: "Skull Servant").keys
  end

  it "o uso de cartas, só para quem venceu" do
    used = { "spells" => 12, "traps" => 10, "fusion_summons" => 2, "ritual_summons" => 1, "tribute_summons" => 3 }
    assert_equal({ "spells" => 24, "traps" => 20, "fusion" => 8, "ritual" => 4, "tribute" => 12 }, dp(duel: used).slice("spells", "traps", "fusion", "ritual", "tribute"))
    assert_equal [ 15, 15, 10 ], dp(duel: { "spells" => 0, "traps" => 0, "special_summons" => 0 }).values_at("no_spells", "no_traps", "no_special")
    assert_equal [ nil, nil ], dp(duel: { "spells" => 9 }).values_at("spells", "no_spells")
    assert_empty dp(result: :loss, duel: used.merge("special_summons" => 0)).keys & %w[spells traps fusion no_special]
  end

  it "os feitos do duelo valem ganhando ou não" do
    feats = { "max_chain" => 4, "max_atk" => 3_800, "max_attack_damage" => 4_100, "max_reflected" => 1_250, "battle_destroyed" => 10,
              "effect_destroyed" => 11, "banished" => 12, "hand_discards" => 13, "deck_discards" => 14, "returned" => 15, "coin_streak" => 3,
              "spell_counters_added" => 5, "unions" => 2, "same_three" => true, "full_field" => true }
    expected = { "chain" => 8, "max_atk" => 7, "max_damage" => 16, "reflected" => 12, "battle_destroyed" => 40, "effect_destroyed" => 44,
                 "banished" => 48, "hand_discards" => 52, "deck_discards" => 56, "returned" => 60, "luck" => 6, "spell_counters" => 20,
                 "unions" => 12, "same_card" => 5, "full_field" => 10 }

    assert_equal expected, dp(result: :loss, duel: feats).slice(*expected.keys)
    assert_includes labels(duel: feats), "11 cartas destruídas por efeito"
  end

  it "os feitos abaixo do mínimo não pagam" do
    small = { "max_chain" => 2, "max_atk" => 2_999, "max_attack_damage" => 2_999, "max_reflected" => 99, "battle_destroyed" => 9,
              "coin_streak" => 1, "spell_counters_added" => 4 }

    assert_equal %w[level loss turns], dp(result: :loss, duel: small).keys
  end

  it "invocou ou usou certas cartas" do
    lines = dp(result: :loss, summoned: [ "Gate Guardian", "Elemental HERO Avian" ], used: [ "Dark Scorpion Retreat" ])

    assert_equal [ 30, 30 ], lines.values_at("summoned", "used")
    assert_includes labels(summoned: [ "Gate Guardian" ]), "Invocou Gate Guardian"
  end
end
