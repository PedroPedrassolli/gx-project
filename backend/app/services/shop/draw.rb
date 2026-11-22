module Shop
  # O sorteio de um pacote (escopo 3.4; ADR 0005 item 7): cada carta sorteia primeiro a
  # raridade, com os pesos comum 75, rara 18, super rara 5 e ultra rara 2, só entre as
  # raridades que o pacote tem, e depois uma carta dessa raridade. A última carta é a de
  # raridade aumentada, como no jogo de referência: sai rara ou melhor (nos mesmos pesos) e
  # vem marcada com rare_slot. Quem chama passa o gerador, criado com a semente que fica gravada.
  module Draw
    WEIGHTS = { "common" => 75, "rare" => 18, "super_rare" => 5, "ultra_rare" => 2 }.freeze

    module_function

    # by_rarity: { "common" => [id da carta, ...], ... }. Devolve [{ id:, rarity: }, ...].
    def call(by_rarity, count, rng)
      weights = WEIGHTS.slice(*by_rarity.keys)
      upgraded = weights.except("common")
      Array.new(count) do |index|
        # Pacote sem rara não tem como aumentar: a última sai como as outras.
        boosted = index == count - 1 && upgraded.any?
        rarity = pick(boosted ? upgraded : weights, rng)
        cards = by_rarity.fetch(rarity)
        card = { id: cards[rng.rand(cards.size)], rarity: }
        card[:rare_slot] = true if boosted
        card
      end
    end

    def pick(weights, rng)
      roll = rng.rand(weights.values.sum)
      weights.find { |_rarity, weight| (roll -= weight).negative? }.first
    end
  end
end
