module Decks
  # Regras do deck (escopo 3.3). Não lê o banco: recebe as linhas do deck, as cartas, a
  # banlist e a coleção do jogador, e devolve os erros prontos para a tela.
  class Validator
    SIZES = { "main" => 40..60, "extra" => 0..15, "side" => 0..15 }.freeze
    SECTION_NAMES = { "main" => "Main Deck", "extra" => "Extra Deck", "side" => "Side Deck" }.freeze
    MAX_COPIES = 3
    # Quantas cópias cada situação da banlist deixa usar.
    BANLIST_COPIES = { "forbidden" => 0, "limited" => 1, "semi_limited" => 2 }.freeze
    EXTRA_DECK_TYPES = %w[Fusion Synchro].freeze

    # cards: { id => Card }; banlist: { id da carta => situação }; collection: { id da
    # carta => quantas o jogador tem }. Banlist vazia é sala sem banlist.
    def initialize(entries:, cards:, banlist:, collection:)
      @entries = entries
      @cards = cards
      @banlist = banlist
      @collection = collection
    end

    def valid? = errors.empty?

    # Os erros de tamanho vêm primeiro; depois, os de cada carta, pela ordem do nome.
    def errors
      @errors ||= size_errors + card_errors
    end

    private

    def size_errors
      SIZES.filter_map do |section, sizes|
        count = @entries.select { |entry| entry.section == section }.sum(&:quantity)
        next if sizes.cover?(count)

        if sizes.min.zero?
          "O #{SECTION_NAMES[section]} pode ter até #{sizes.max} cartas (tem #{count})."
        else
          "O #{SECTION_NAMES[section]} precisa ter de #{sizes.min} a #{sizes.max} cartas (tem #{count})."
        end
      end
    end

    def card_errors
      rows_by_card = @entries.group_by(&:card_id)
      unknown, known = rows_by_card.keys.partition { |card_id| @cards[card_id].nil? }
      known.sort_by { |card_id| @cards[card_id].name }.flat_map { |card_id| errors_for(@cards[card_id], rows_by_card[card_id]) } +
        unknown.map { |card_id| "A carta #{card_id} não está no pool." }
    end

    def errors_for(card, rows)
      copies = rows.sum(&:quantity)
      [
        copies_error(card, copies),
        banlist_error(card, copies),
        collection_error(card, copies),
        *rows.map { |row| place_error(card, row) },
        *rows.map { |row| destiny_error(card, row) }
      ].compact
    end

    def copies_error(card, copies)
      "#{card.name}: no máximo #{MAX_COPIES} cópias somando Main, Extra e Side (tem #{copies})." if copies > MAX_COPIES
    end

    def banlist_error(card, copies)
      case @banlist[card.id]
      when "forbidden" then "#{card.name} está proibida."
      when "limited" then "#{card.name} é limitada: no máximo 1 cópia (tem #{copies})." if copies > 1
      when "semi_limited" then "#{card.name} é semi-limitada: no máximo 2 cópias (tem #{copies})." if copies > 2
      end
    end

    def collection_error(card, copies)
      owned = @collection.fetch(card.id, 0)
      "#{card.name}: você tem #{owned} e o deck usa #{copies}." if copies > owned
    end

    # Fusão e Sincro ficam no Extra; o Side aceita qualquer carta.
    def place_error(card, row)
      extra_type = card.monster_types.intersect?(EXTRA_DECK_TYPES)
      if extra_type && row.section == "main"
        "#{card.name} é de Fusão ou Sincro: vai no Extra Deck."
      elsif !extra_type && row.section == "extra"
        "#{card.name} não é de Fusão nem Sincro: não vai no Extra Deck."
      end
    end

    # A Destiny sorteada sai do Main Deck (escopo 1.2).
    def destiny_error(card, row)
      "#{card.name} só pode ser Destiny no Main Deck." if row.destiny && row.section != "main"
    end
  end
end
