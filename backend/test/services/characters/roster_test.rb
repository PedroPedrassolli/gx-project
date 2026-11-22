require "test_helper"

describe Characters::Roster do
  let(:roster) { Characters::Roster.all }

  it "tem os 14 personagens na ordem, de alunos a lendas, com o Yugi por último" do
    _(roster.map(&:id)).must_equal %w[chumley syrus blair alexis chazz bastion zane crowler jesse aster jaden joey kaiba yugi]
    _(roster.map(&:position)).must_equal (1..14).to_a
    _(roster.chunk_while { |one, other| one.group == other.group }.map { |group| group.first.group.id }).must_equal %w[alunos chefes lendas]
    _(roster.map(&:skill)).must_equal [ 1 ] * 6 + [ 2 ] * 5 + [ 3 ] * 3
  end

  it "acha pelo id e diz quem vem depois" do
    chumley = Characters::Roster.find("chumley")

    _(chumley.name).must_equal "Chumley"
    _(chumley.group.name).must_equal "Alunos da Academia"
    _(Characters::Roster.after(chumley).id).must_equal "syrus"
    _(Characters::Roster.after(Characters::Roster.find("yugi"))).must_be_nil
    _(Characters::Roster.find("pegasus")).must_be_nil
  end

  it "paga mais quanto mais longe na ordem" do
    _(Characters::Roster.find("chumley").victory_bonus).must_equal 60
    _(Characters::Roster.find("yugi").victory_bonus).must_equal 840
  end

  # Os decks contra o pool do jogo (cartas.yml e cobertura.yml), sem banco: toda carta tem
  # código na engine e o deck segue as regras de tamanho e cópias. A banlist não vale: os
  # decks dos personagens no jogo de referência também não seguem.
  describe "os decks" do
    def self.pool
      @pool ||= begin
        seeds = Rails.root.join("db/seeds/jogo")
        exceptions = GameData::Pool.exceptions(seeds)
        YAML.safe_load_file(seeds.join("cartas.yml")).to_h { |card| [ card["nome"], card.merge("codigo" => GameData::Pool.engine_code(card, exceptions)) ] }
      end
    end

    let(:pool) { self.class.pool }
    let(:extra_types) { %w[Fusion Synchro] }

    it "têm só cartas do pool, com código na engine" do
      roster.each do |character|
        missing = character.deck.card_names.reject { |name| pool[name]&.fetch("codigo") }

        _(missing).must_be_empty "#{character.id}: fora do pool"
      end
    end

    it "têm o tamanho e as cópias que a regra deixa, cada carta no deck certo" do
      roster.each do |character|
        deck = character.deck
        copies = deck.main.merge(deck.extra) { |_name, main, extra| main + extra }

        _(40..60).must_include deck.main.values.sum
        _(deck.extra.values.sum).must_be :<=, 15
        _(copies.select { |_name, count| count > 3 }).must_be_empty "#{character.id}: mais de 3 cópias"
        _(deck.main.keys.select { |name| pool[name]["tipos"].to_a.intersect?(extra_types) }).must_be_empty "#{character.id}: Extra no Main"
        _(deck.extra.keys.reject { |name| pool[name]["tipos"].to_a.intersect?(extra_types) }).must_be_empty "#{character.id}: Main no Extra"
      end
    end

    it "têm a carta-símbolo e as cartas que entraram nas trocas" do
      roster.each do |character|
        deck = character.deck

        _(deck.card_names).must_include character.signature
        deck.swaps.each do |swap|
          _(pool[swap["sai"]]).must_be_nil "#{character.id}: #{swap['sai']} está no pool, não precisa de troca"
          _(deck.main.fetch(swap["entra"])).must_be :>=, swap["quantidade"]
        end
      end
      _(roster.select { |character| character.deck.swaps.any? }.map(&:id)).must_equal %w[kaiba yugi]
    end

    it "guardam o nome, o nível e a fonte de cada deck" do
      roster.each do |character|
        _(character.deck.name).must_be :present?
        _(1..10).must_include character.deck.level
        _(character.deck.source).must_be_kind_of Integer
        _(character.description).must_be :present?
      end
    end
  end
end
