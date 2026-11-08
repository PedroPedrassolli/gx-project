module Decks
  # Salva o nome e as cartas de um deck (ADR 0009). As cartas trocam todas de uma vez, e
  # carta repetida na mesma seção é somada. Deck incompleto pode ser salvo (rascunho); o
  # que a tabela não aceita volta como erro: seção que não existe, menos de 1 ou mais de 3
  # cópias numa linha e carta fora do pool.
  class Editor
    # Linhas por pedido: um deck tem no máximo 90 cartas (60 + 15 + 15), então 200 sobra.
    MAX_ROWS = 200

    attr_reader :deck

    # Linhas do pedido somadas por carta e seção: [{ card_id:, section:, quantity:, destiny: }].
    def self.merge(cards)
      cards.group_by { |row| [ integer(row[:card_id]), row[:section].to_s ] }.map do |(card_id, section), rows|
        { card_id:, section:, quantity: rows.sum { |row| integer(row[:quantity]) },
          destiny: rows.any? { |row| ActiveModel::Type::Boolean.new.cast(row[:destiny]) } }
      end
    end

    # Número inteiro do pedido. O que não é (texto, booleano, 1.5) vira 0, que a validação
    # recusa ("carta 0", "tem 0 cópias").
    def self.integer(value) = Integer(value.to_s, 10, exception: false) || 0

    def initialize(deck)
      @deck = deck
    end

    # name: nil mantém o nome; cards: nil mantém as cartas. Os erros ficam em deck.errors.
    def save(name: nil, cards: nil)
      deck.name = name unless name.nil?
      rows = cards && self.class.merge(cards)
      deck.validate
      card_errors(rows).each { |message| deck.errors.add(:cards, message) } if rows
      return false if deck.errors.any?

      Deck.transaction do
        deck.save!
        replace_cards(rows) if rows
      end
      true
    end

    private

    def replace_cards(rows)
      deck.deck_cards.delete_all
      DeckCard.insert_all!(rows.map { |row| row.merge(deck_id: deck.id) }) if rows.any?
      deck.deck_cards.reset
      deck.touch
    end

    def card_errors(rows)
      names = Card.where(id: rows.pluck(:card_id)).pluck(:id, :name).to_h
      rows.flat_map do |row|
        name = names[row[:card_id]]
        next [ "A carta #{row[:card_id]} não está no pool." ] unless name

        [ ("#{name}: a seção \"#{row[:section]}\" não existe." unless DeckCard::SECTIONS.include?(row[:section])),
          ("#{name}: de 1 a 3 cópias por seção (tem #{row[:quantity]})." unless (1..3).cover?(row[:quantity])) ].compact
      end
    end
  end
end
