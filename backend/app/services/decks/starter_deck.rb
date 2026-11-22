module Decks
  # Deck inicial do jogo (escopo 3.2): toda conta nova ganha as cartas na coleção e o deck
  # montado, com as Destiny. Os dados vêm de db/seeds/jogo/deck_inicial.yml. As cartas do
  # Side do jogo de referência vêm para a coleção, mas não para o deck: o GX não tem Side
  # (GXP-125).
  module StarterDeck
    NAME = "Deck inicial".freeze
    FILE = Rails.root.join("db/seeds/jogo/deck_inicial.yml")
    SECTIONS = { "principal" => "main", "side" => nil }.freeze

    module_function

    def give_to(user)
      entries = self.entries
      now = Time.current
      # Duas inserções em vez de uma por carta: o banco fica em outra cidade.
      user.collection_cards.insert_all!(entries.group_by(&:card_id).map do |card_id, rows|
        # As cartas do deck inicial já chegam vistas: "nova" é a que vem da loja e das missões.
        { card_id:, quantity: rows.sum(&:quantity), obtained_at: now, seen_at: now }
      end)
      user.decks.create!(name: NAME).deck_cards.insert_all!(entries.select(&:section).map(&:to_h))
    end

    # As cartas do deck inicial (Decks::Entry), com o id de cada uma no banco. As do Side vêm
    # sem seção: vão só para a coleção.
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
