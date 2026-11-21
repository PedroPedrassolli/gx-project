module Shop
  # O conversor de cartas (escopo 3.4; GXP-90): de 10 a 99 cartas repetidas viram 1 carta
  # sorteada do grupo da quantidade (db/seeds/jogo/conversor.yml).
  #
  # Só entram cópias repetidas: o jogador sempre fica com uma cópia de cada carta e com as
  # cópias que o deck que mais usa a carta precisa (escopo: nunca a carta de um deck sem cópia
  # sobrando). Tudo numa transação, com o jogador travado e a semente do sorteio gravada; a
  # mesma chave devolve a mesma conversão, sem gastar de novo.
  class Converter
    class Invalid < StandardError; end

    RANGE = 10..99

    # Quantas cópias de cada carta o jogador pode converter: { id da carta => quantas }.
    def self.spare(user)
      owned = user.collection_cards.pluck(:card_id, :quantity)
      kept = Hash.new(1)
      DeckCard.joins(:deck).where(decks: { user_id: user.id }).group(:deck_id, :card_id).sum(:quantity)
              .each { |(_deck, card_id), quantity| kept[card_id] = [ kept[card_id], quantity ].max }
      owned.filter_map { |card_id, quantity| [ card_id, quantity - kept[card_id] ] if quantity > kept[card_id] }.to_h
    end

    # cards: { id da carta => quantas }. key: a chave do pedido, gerada no navegador.
    def initialize(user, cards, key:)
      @user = user
      @cards = cards
      @key = key
    end

    def call
      User.transaction do
        @user.lock!
        @user.card_conversions.find_by(key: @key) || convert
      end
    end

    private

    def convert
      amount = @cards.values.sum
      raise Invalid, "Escolha de #{RANGE.min} a #{RANGE.max} cartas." unless RANGE.cover?(amount)

      spare = self.class.spare(@user)
      unless @cards.all? { |card_id, quantity| quantity.positive? && quantity <= spare.fetch(card_id, 0) }
        raise Invalid, "Só dá para converter as cópias repetidas que nenhum deck usa."
      end

      seed = SecureRandom.random_number(2**62)
      # Ordem fixa: a mesma semente sempre sorteia a mesma carta.
      card_id = ConverterGroup.find_by!(amount:).cards.order(:id).ids.sample(random: Random.new(seed))
      new_card = !@user.collection_cards.exists?(card_id:)
      @cards.each { |id, quantity| @user.collection_cards.where(card_id: id).update_all([ "quantity = quantity - ?", quantity ]) }
      CollectionCard.add!(@user, { card_id => 1 })
      @user.card_conversions.create!(key: @key, amount:, spent: @cards, seed:, card_id:, new_card:)
    end
  end
end
