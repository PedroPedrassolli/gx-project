module Decks
  # O deck do jeito que a engine recebe e a partida guarda (ADR 0011): os códigos do Main
  # embaralhados, o Extra e as cartas marcadas como Destiny.
  module Snapshot
    module_function

    def of(deck)
      rows = deck.deck_cards.to_a
      # Só o código da engine de cada carta, numa consulta (a carta inteira não é usada aqui).
      engine_codes = Card.where(id: rows.map(&:card_id)).pluck(:id, :engine_code).to_h
      codes = ->(section) { rows.select { |row| row.section == section }.flat_map { |row| [ engine_codes.fetch(row.card_id) ] * row.quantity } }
      { main: codes.call("main").shuffle(random: SecureRandom), extra: codes.call("extra"),
        destiny: rows.select { |row| row.section == "main" && row.destiny }.map { |row| engine_codes.fetch(row.card_id) } }
    end
  end
end
