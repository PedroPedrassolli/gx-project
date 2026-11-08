module Decks
  # Deck inicial do jogo (escopo 3.2): toda conta nova ganha as cartas na coleção e o deck
  # montado, com Side e as Destiny. Os dados vêm de db/seeds/jogo/deck_inicial.yml.
  module StarterDeck
    NAME = "Deck inicial".freeze
    FILE = Rails.root.join("db/seeds/jogo/deck_inicial.yml")
    SECTIONS = { "principal" => "main", "side" => "side" }.freeze

    module_function

    def give_to(user)
      entries = self.entries
      now = Time.current
      # Duas inserções em vez de uma por carta: o banco fica em outra cidade.
      user.collection_cards.insert_all!(entries.group_by(&:card_id).map do |card_id, rows|
        { card_id:, quantity: rows.sum(&:quantity), obtained_at: now }
      end)
      user.decks.create!(name: NAME).deck_cards.insert_all!(entries.map(&:to_h))
    end

    # As linhas do deck (Decks::Entry), com o id de cada carta no banco.
    def entries
      deck = YAML.safe_load_file(FILE)
      card_ids = Card.where(passcode: SECTIONS.keys.flat_map { |key| deck[key] }.pluck("passcode")).pluck(:passcode, :id).to_h
      SECTIONS.flat_map do |key, section|
        deck[key].map do |row|
          card_id = card_ids.fetch(row["passcode"]) { raise "Carta do deck inicial fora do banco: #{row["nome"]}" }
          Entry.new(card_id:, section:, quantity: row["quantidade"], destiny: deck["destiny"].include?(row["nome"]))
        end
      end
    end
  end
end
