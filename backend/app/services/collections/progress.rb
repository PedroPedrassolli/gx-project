module Collections
  # Quanto do pool e de cada pacote o jogador já tem (escopo 3.2): conta cartas diferentes,
  # não cópias. A loja vai usar essa porcentagem para liberar pacotes (F4).
  class Progress
    def initialize(user)
      @owned_ids = user.collection_cards.select(:card_id)
    end

    def total = counts(owned: Card.where(id: @owned_ids).count, cards: Card.count)

    # Um item por pacote, na ordem da loja.
    def packs
      cards = PackCard.group(:pack_id).count
      owned = PackCard.where(card_id: @owned_ids).group(:pack_id).count
      Pack.order(:position).ids.map { |id| { id:, **counts(owned: owned.fetch(id, 0), cards: cards.fetch(id, 0)) } }
    end

    private

    def counts(owned:, cards:)
      { owned:, cards:, percent: cards.zero? ? 0.0 : (owned * 100.0 / cards).round(1) }
    end
  end
end
