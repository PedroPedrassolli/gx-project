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

  it "a última carta do pacote sai rara ou melhor, nos pesos 18, 5 e 2, e vem marcada" do
    lasts = Array.new(5_000) { |seed| Shop::Draw.call(BY_RARITY, 5, Random.new(seed)).last }
    shares = lasts.pluck(:rarity).tally.transform_values { |count| count / 50.0 }

    assert_nil shares["common"]
    { "rare" => 72, "super_rare" => 20, "ultra_rare" => 8 }.each do |rarity, share|
      assert_in_delta share, shares[rarity], 3.0, rarity
    end
    assert(lasts.all? { |card| card[:rare_slot] })
  end

  it "só a última carta é a garantida; num pacote sem rara, ela sai comum e sem marca" do
    assert_equal [ nil, nil, nil, nil, true ], Shop::Draw.call(BY_RARITY, 5, Random.new(3)).pluck(:rare_slot)

    only_common = Shop::Draw.call({ "common" => [ 1 ] }, 5, Random.new(3))
    assert_equal [ "common" ] * 5, only_common.pluck(:rarity)
    assert_nil only_common.last[:rare_slot]
  end

  it "só sorteia entre as raridades que o pacote tem" do
    cards = Shop::Draw.call({ "rare" => [ 3 ], "ultra_rare" => [ 5 ] }, 500, Random.new(1))

    assert_equal %w[rare ultra_rare], cards.pluck(:rarity).uniq.sort
    assert_equal [ 3, 5 ], cards.pluck(:id).uniq.sort
  end
end
