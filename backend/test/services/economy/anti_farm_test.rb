require "test_helper"

class Economy::AntiFarmTest < ActiveSupport::TestCase
  def apply(subtotal, short: false, earned_today: 0) = Economy::AntiFarm.apply(subtotal, short:, earned_today:)

  it "duelo normal paga tudo, sem corte, mesmo jogando de novo com a mesma pessoa" do
    assert_equal({ total: 800, cuts: [] }, apply(800))
  end

  it "duelo curto paga só 10" do
    result = apply(800, short: true)
    assert_equal [ 10, [ "short" ], -790 ], [ result[:total], result[:cuts].pluck(:key), result[:cuts].sole[:dp] ]
  end

  it "teto diário de 15.000 DP em duelos, igual para conta nova" do
    assert_equal 300, apply(800, earned_today: 14_700)[:total]
    assert_equal 0, apply(800, earned_today: 15_200)[:total]
    result = apply(800, earned_today: 14_700)
    assert_equal [ "Teto de 15.000 DP por dia em duelos", -500 ], result[:cuts].sole.values_at(:label, :dp)
  end
end
