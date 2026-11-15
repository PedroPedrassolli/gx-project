require "test_helper"

class Shop::DrawTest < ActiveSupport::TestCase
  BY_RARITY = { "common" => [ 1, 2 ], "rare" => [ 3 ], "super_rare" => [ 4 ], "ultra_rare" => [ 5 ] }.freeze

  it "a mesma semente sorteia as mesmas cartas" do
    assert_equal Shop::Draw.call(BY_RARITY, 5, Random.new(42)), Shop::Draw.call(BY_RARITY, 5, Random.new(42))
  end

  it "as raridades saem perto dos pesos 75, 18, 5 e 2" do
    shares = Shop::Draw.call(BY_RARITY, 20_000, Random.new(7)).pluck(:rarity).tally.transform_values { |count| count / 200.0 }

    { "common" => 75, "rare" => 18, "super_rare" => 5, "ultra_rare" => 2 }.each do |rarity, weight|
      assert_in_delta weight, shares[rarity], 1.0, rarity
    end
  end

  it "só sorteia entre as raridades que o pacote tem" do
    cards = Shop::Draw.call({ "rare" => [ 3 ], "ultra_rare" => [ 5 ] }, 500, Random.new(1))

    assert_equal %w[rare ultra_rare], cards.pluck(:rarity).uniq.sort
    assert_equal [ 3, 5 ], cards.pluck(:id).uniq.sort
  end
end
