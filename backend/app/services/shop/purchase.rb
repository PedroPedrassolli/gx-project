module Shop
  # A compra de 1 ou 10 pacotes (escopo 3.4; ADR 0005 itens 2, 3 e 7), toda numa transação: o
  # jogador travado, o pacote liberado para ele, o débito no razão, o sorteio com a semente
  # gravada e as cartas na coleção. A mesma chave devolve a mesma compra, sem cobrar de novo
  # (o clique duplo e a rede que repete o pedido).
  class Purchase
    COUNTS = [ 1, 10 ].freeze

    # O pacote ainda não está liberado para o jogador.
    class Unavailable < StandardError; end

    def initialize(user, pack, count:, key:)
      @user = user
      @pack = pack
      @count = count
      @key = key
    end

    # Devolve os pacotes abertos (PackOpening), na ordem.
    def call
      User.transaction do
        @user.lock!
        done = @user.pack_openings.where(purchase_key: @key).order(:position).to_a
        done.presence || buy
      end
    end

    private

    def buy
      raise Unavailable, "Este pacote ainda não está liberado para você." unless Availability.for(@user).call(@pack.availability)[:available]

      Economy::Ledger.post!(@user, -@pack.price * @count, reason: "pack", key: "compra:#{@key}", ref: @pack)
      seed = SecureRandom.random_number(2**62)
      rng = Random.new(seed)
      by_rarity = @pack.pack_cards.pluck(:rarity, :card_id).group_by(&:first).transform_values { |rows| rows.map(&:last) }
      drawn = Array.new(@count) { Draw.call(by_rarity, @pack.cards_per_pack, rng) }
      mark_new(drawn)
      add_to_collection(drawn.flatten)
      drawn.each_with_index.map do |cards, position|
        @user.pack_openings.create!(pack: @pack, purchase_key: @key, position:, seed:, cards:)
      end
    end

    # Nova é a carta que o jogador ainda não tinha (só a primeira cópia dela na compra).
    def mark_new(drawn)
      seen = @user.collection_cards.where(card_id: drawn.flatten.pluck(:id)).pluck(:card_id).to_set
      drawn.flatten.each { |card| card[:new] = seen.add?(card[:id]).present? }
    end

    def add_to_collection(cards)
      now = Time.current
      rows = cards.pluck(:id).tally.map { |card_id, quantity| { user_id: @user.id, card_id:, quantity:, obtained_at: now } }
      CollectionCard.upsert_all(rows, unique_by: %i[user_id card_id], record_timestamps: true,
                                      on_duplicate: Arel.sql("quantity = collection_cards.quantity + EXCLUDED.quantity, updated_at = EXCLUDED.updated_at"))
    end
  end
end
