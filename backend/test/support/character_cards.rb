# Grava no banco de teste as cartas do deck de um personagem (Characters::Roster), com os dados
# reais de db/seeds/jogo/cartas.yml e o código da engine do cobertura.yml. Carta que já está no
# banco (do deck inicial, por exemplo) fica como está.
module CharacterCards
  SEEDS = Rails.root.join("db/seeds/jogo")

  def self.pool = @pool ||= YAML.safe_load_file(SEEDS.join("cartas.yml")).index_by { |card| card["nome"] }
  def self.exceptions = @exceptions ||= GameData::Pool.exceptions(SEEDS)

  def self.row(card)
    { engine_code: GameData::Pool.engine_code(card, exceptions), passcode: card["passcode"], name: card["nome"],
      card_type: card["tipo"], monster_types: card["tipos"].to_a, level: card["nivel"], attack: card["atk"], defense: card["def"],
      image_code: card["passcode"], source_revision: card["fonte"] }
  end

  def load_character_cards(id)
    names = Characters::Roster.find(id).deck.card_names
    missing = names - Card.where(name: names).pluck(:name)
    Card.insert_all!(missing.map { |name| CharacterCards.row(CharacterCards.pool.fetch(name)) }) if missing.any?
  end
end
