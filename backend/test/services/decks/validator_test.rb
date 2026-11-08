require "test_helper"

class Decks::ValidatorTest < ActiveSupport::TestCase
  # Cartas 1 a 21 são monstros comuns; 100 é de Fusão e 101 é Sincro. Nada vai para o banco.
  let(:cards) do
    monsters = (1..21).to_h { |id| [ id, Card.new(id:, name: "Monstro #{id}", monster_types: [ "Normal" ]) ] }
    monsters.merge(100 => Card.new(id: 100, name: "Herói de Fusão", monster_types: %w[Fusion Effect]),
                   101 => Card.new(id: 101, name: "Guerreiro Sincro", monster_types: %w[Synchro]))
  end
  # O jogador tem 3 cópias de cada carta, salvo quando o teste diz outra coisa.
  let(:collection) { cards.keys.index_with(3) }

  def entry(card_id, section, quantity, destiny: false) = Decks::Entry.new(card_id:, section:, quantity:, destiny:)

  # Main de 40 cartas: 2 cópias de cada uma das cartas 1 a 20.
  def main_deck(copies: 2, ids: 1..20) = ids.map { |id| entry(id, "main", copies) }

  def errors(entries, banlist: {}, collection: self.collection)
    Decks::Validator.new(entries:, cards:, banlist:, collection:).errors
  end

  it "aceita um Main de 40 cartas, sem Extra nem Side" do
    _(errors(main_deck)).must_be_empty
    _(Decks::Validator.new(entries: main_deck, cards:, banlist: {}, collection:)).must_be :valid?
  end

  it "pede de 40 a 60 cartas no Main" do
    _(errors(main_deck(ids: 1..19) + [ entry(20, "main", 1) ])).must_equal [ "O Main Deck precisa ter de 40 a 60 cartas (tem 39)." ]
    _(errors(main_deck(copies: 3) + [ entry(21, "main", 1) ])).must_equal [ "O Main Deck precisa ter de 40 a 60 cartas (tem 61)." ]
    _(errors(main_deck(copies: 3))).must_be_empty
  end

  it "aceita até 15 cartas no Extra e no Side" do
    side = (1..5).map { |id| entry(id, "side", 1) } + [ entry(21, "side", 3) ] + (6..12).map { |id| entry(id, "side", 1) }
    extra = [ entry(100, "extra", 3), entry(101, "extra", 3) ]

    _(errors(main_deck + side + extra)).must_be_empty
    _(errors(main_deck + side + [ entry(13, "side", 1) ])).must_equal [ "O Side Deck pode ter até 15 cartas (tem 16)." ]
  end

  it "limita a 3 cópias somando Main, Extra e Side, mesmo para quem tem mais" do
    collection = self.collection.merge(1 => 4)

    _(errors(main_deck + [ entry(1, "side", 2) ], collection:)).must_equal [ "Monstro 1: no máximo 3 cópias somando Main, Extra e Side (tem 4)." ]
  end

  it "segue a banlist, somando as seções" do
    banlist = { 1 => "forbidden", 2 => "limited", 3 => "semi_limited", 4 => "semi_limited" }
    deck = main_deck + [ entry(4, "side", 1) ]

    _(errors(deck, banlist:)).must_equal [ "Monstro 1 está proibida.", "Monstro 2 é limitada: no máximo 1 cópia (tem 2).",
                                          "Monstro 4 é semi-limitada: no máximo 2 cópias (tem 3)." ]
  end

  it "só aceita as cartas que o jogador tem, somando as seções" do
    collection = self.collection.merge(1 => 2, 2 => 0)
    deck = main_deck + [ entry(1, "side", 1) ]

    _(errors(deck, collection:)).must_equal [ "Monstro 1: você tem 2 e o deck usa 3.", "Monstro 2: você tem 0 e o deck usa 2." ]
  end

  it "põe Fusão e Sincro só no Extra, e nada mais no Extra" do
    deck = main_deck(ids: 1..19) + [ entry(100, "main", 2), entry(20, "extra", 2), entry(101, "side", 1) ]

    _(errors(deck)).must_equal [ "Herói de Fusão é de Fusão ou Sincro: vai no Extra Deck.",
                                 "Monstro 20 não é de Fusão nem Sincro: não vai no Extra Deck." ]
  end

  it "aceita Destiny em quantas cartas do Main quiser, mas só no Main" do
    deck = main_deck(ids: 1..17) + [ 18, 19, 20 ].map { |id| entry(id, "main", 2, destiny: true) }

    _(errors(deck)).must_be_empty
    _(errors(deck + [ entry(21, "side", 1, destiny: true) ])).must_equal [ "Monstro 21 só pode ser Destiny no Main Deck." ]
  end

  it "avisa da carta que não está no pool" do
    _(errors(main_deck + [ entry(999, "side", 1) ])).must_equal [ "A carta 999 não está no pool." ]
  end
end

class Decks::ValidatorStarterDeckTest < ActiveSupport::TestCase
  SEEDS = Rails.root.join("db/seeds/jogo")

  def seed(name) = YAML.safe_load_file(SEEDS.join("#{name}.yml"))

  it "aceita o deck inicial do jogo, com a banlist do jogo" do
    deck = seed("deck_inicial")
    names = (deck["principal"] + deck["side"]).map { |card| card["nome"] }
    cards = seed("cartas").select { |card| names.include?(card["nome"]) }
      .to_h { |card| [ card["passcode"], Card.new(id: card["passcode"], name: card["nome"], monster_types: card["tipos"].to_a) ] }
    banlist = seed("banlist")["cartas"].to_h { |card| [ card["passcode"], Catalog::Importer::STATUSES[card["status"]] ] }
    entries = { "main" => deck["principal"], "side" => deck["side"] }.flat_map do |section, rows|
      rows.map { |row| Decks::Entry.new(row["passcode"], section, row["quantidade"], deck["destiny"].include?(row["nome"])) }
    end
    collection = entries.group_by(&:card_id).transform_values { |rows| rows.sum(&:quantity) }

    validator = Decks::Validator.new(entries:, cards:, banlist:, collection:)

    _(validator.errors).must_be_empty
    _(cards.size).must_equal names.uniq.size
    _(entries.count(&:destiny)).must_equal 3
  end
end
