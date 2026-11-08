# Grava no banco de teste só as cartas do deck inicial do jogo, com os dados reais de
# db/seeds/jogo/cartas.yml. O pool inteiro deixaria a suíte lenta; o arquivo é lido uma vez.
module StarterDeckCards
  def self.rows
    @rows ||= begin
      deck = YAML.safe_load_file(Decks::StarterDeck::FILE)
      passcodes = (deck["principal"] + deck["side"]).pluck("passcode")
      YAML.safe_load_file(Rails.root.join("db/seeds/jogo/cartas.yml"))
        .select { |card| passcodes.include?(card["passcode"]) }
        .map do |card|
          { engine_code: card["passcode"], passcode: card["passcode"], name: card["nome"], card_type: card["tipo"],
            monster_types: card["tipos"].to_a, source_revision: card["fonte"] }
        end
    end
  end

  def load_starter_deck_cards = Card.insert_all!(StarterDeckCards.rows)
end
