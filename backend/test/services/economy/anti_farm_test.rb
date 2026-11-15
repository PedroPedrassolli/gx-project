require "test_helper"

class Economy::AntiFarmTest < ActiveSupport::TestCase
  def apply(subtotal, short: false, earlier_today: 0, earned_today: 0, new_account: false)
    Economy::AntiFarm.apply(subtotal, short:, earlier_today:, earned_today:, new_account:)
  end

  it "duelo normal, o primeiro do dia contra esse oponente: paga tudo, sem corte" do
    assert_equal({ total: 300, cuts: [] }, apply(300))
  end

  it "duelo curto paga só a derrota" do
    result = apply(300, short: true)
    assert_equal [ 10, [ "short" ], -290 ], [ result[:total], result[:cuts].pluck(:key), result[:cuts].sole[:dp] ]
  end

  it "mesmo oponente no mesmo dia: metade, um quarto e depois nada" do
    assert_equal [ 150, 75, 0, 0 ], (1..4).map { |earlier| apply(300, earlier_today: earlier)[:total] }
    assert_equal "2º duelo contra o mesmo oponente hoje", apply(300, earlier_today: 1)[:cuts].sole[:label]
  end

  it "teto diário de 3.000 DP, e de 1.500 para conta nova" do
    assert_equal 100, apply(300, earned_today: 2_900)[:total]
    assert_equal 0, apply(300, earned_today: 3_200)[:total]
    result = apply(300, earned_today: 1_400, new_account: true)
    assert_equal [ 100, "Teto de 1.500 DP por dia em duelos" ], [ result[:total], result[:cuts].sole[:label] ]
  end
end
