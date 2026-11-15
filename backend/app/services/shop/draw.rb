module Shop
  # O sorteio de um pacote (escopo 3.4; ADR 0005 item 3): cada carta sorteia primeiro a
  # raridade, com os pesos comum 75, rara 18, super rara 5 e ultra rara 2, só entre as
  # raridades que o pacote tem, e depois uma carta dessa raridade. Quem chama passa o gerador,
  # criado com a semente que fica gravada.
  module Draw
    WEIGHTS = { "common" => 75, "rare" => 18, "super_rare" => 5, "ultra_rare" => 2 }.freeze

    module_function

    # by_rarity: { "common" => [id da carta, ...], ... }. Devolve [{ id:, rarity: }, ...].
    def call(by_rarity, count, rng)
      weights = WEIGHTS.slice(*by_rarity.keys)
      total = weights.values.sum
      Array.new(count) do
        roll = rng.rand(total)
        rarity, = weights.find { |_rarity, weight| (roll -= weight).negative? }
        cards = by_rarity.fetch(rarity)
        { id: cards[rng.rand(cards.size)], rarity: }
      end
    end
  end
end
