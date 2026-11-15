require "test_helper"

class Economy::BonusCalculatorTest < ActiveSupport::TestCase
  # Um duelo comum: 6 turnos, nível 1 contra nível 12, vencido na engine com 3.000 PV e 20
  # cartas no deck, no próprio turno.
  def stats(**changes)
    { result: :win, turns: 6, level: 1, opponent_level: 12, engine_win: true, win_reason: 1, lp: 3_000, deck: 20,
      opponent_turn: false }.merge(changes)
  end

  def dp(**changes) = Economy::BonusCalculator.lines(stats(**changes)).to_h { |line| [ line[:key], line[:dp] ] }

  it "vitória: nível, 2 por turno, vitória em rede e 90 por faixa de nível do oponente" do
    assert_equal({ "level" => 2, "turns" => 12, "network_win" => 50, "duelist" => 180 }, dp)
    assert_equal "Oponente de nível 12", Economy::BonusCalculator.lines(stats).last[:label]
  end

  it "derrota e empate: o próprio bônus e 1 por turno" do
    assert_equal({ "level" => 4, "loss" => 10, "turns" => 6 }, dp(result: :loss, level: 2))
    assert_equal({ "level" => 2, "draw" => 50, "turns" => 6 }, dp(result: :draw))
  end

  it "as formas de vencer do Anexo A" do
    assert_equal 10, dp(turns: 5)["quick"]
    assert_equal 20, dp(opponent_turn: true)["opponent_turn"]
    assert_equal 20, dp(win_reason: 2)["no_cards"]
    assert_equal [ 20, 100 ], dp(lp: 50).values_at("low_lp", "very_low_lp")
    assert_equal [ 20, nil ], dp(lp: 999).values_at("low_lp", "very_low_lp")
    assert_equal 100, dp(lp: 20_001)["high_lp"]
    assert_equal 573, dp(lp: 5_730)["konami"]
    assert_equal [ 20, 100 ], dp(deck: 0).values_at("low_deck", "empty_deck")
    assert_equal({ "exodia" => 50, "destiny_board" => 100 }, dp(win_reason: 0x10).slice("exodia").merge(dp(win_reason: 0x15).slice("destiny_board")))
  end

  it "desistência ou tempo não valem as formas de vencer" do
    assert_equal %w[level turns network_win duelist], dp(engine_win: false, lp: 5_730, turns: 3).keys
  end
end
