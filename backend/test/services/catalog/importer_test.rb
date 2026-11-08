require "test_helper"

describe Catalog::Importer do
  let(:importer) { Catalog::Importer.new(Rails.root.join("test/fixtures/files/catalogo")) }

  def card(code) = Card.find_by!(engine_code: code)
  def pack(name) = Pack.find_by!(name:)

  it "grava as cartas do pool pelo código da engine, sem as que saíram do pool" do
    importer.run

    _(Card.order(:engine_code).pluck(:engine_code, :name)).must_equal [
      [ 110, "Night Assailant" ], [ 200, "Trap Hole" ], [ 500, "Ancient Gear" ], [ 700, "Cyril" ], [ 900, "Clear Wall" ]
    ]
    _(card(900).slice(:passcode, :internal_number, :source_revision)).must_equal({ "passcode" => nil, "internal_number" => 3, "source_revision" => 3 })
  end

  it "grava o que o jogador vê de cada carta" do
    importer.run

    _(card(110).slice(:card_type, :card_attribute, :race, :monster_types, :level, :attack, :defense, :name_pt))
      .must_equal({ "card_type" => "Monster", "card_attribute" => "DARK", "race" => "Fiend",
                    "monster_types" => [ "Flip", "Effect" ], "level" => 3, "attack" => 200, "defense" => 500,
                    "name_pt" => "Assaltante Noturno" })
    _(card(200).text).must_equal "Destroy it."
    _(card(200).slice(:card_type, :property, :monster_types, :text_pt))
      .must_equal({ "card_type" => "Trap", "property" => "Normal", "monster_types" => [], "text_pt" => nil })
  end

  it "mostra o texto da época da carta pré-errata, sem o português, que é do texto atual" do
    importer.run

    _(card(110).slice(:text, :text_pt, :name_pt)).must_equal({ "text" => "FLIP: Destroy 1 monster.", "text_pt" => nil,
                                                               "name_pt" => "Assaltante Noturno" })
  end

  it "guarda a imagem: a do passcode, a da carta oficial na pré-errata e a da impressão" do
    importer.run

    _(Card.order(:engine_code).pluck(:engine_code, :image_code)).must_equal [ [ 110, 100 ], [ 200, 200 ], [ 500, 500 ],
                                                                             [ 700, 700 ], [ 900, nil ] ]
  end

  it "mostra os dados da carta impressa quando a carta do anime usa a oficial" do
    importer.run

    _(card(700).slice(:name, :card_type, :property, :card_attribute, :level, :text, :name_pt, :source_revision))
      .must_equal({ "name" => "Cyril", "card_type" => "Monster", "property" => nil, "card_attribute" => "LIGHT",
                    "level" => 4, "text" => "Printed text.", "name_pt" => "Cirilo", "source_revision" => 70 })
  end

  it "grava os pacotes com a disponibilidade e monta os que juntam outros" do
    importer.run

    _(pack("Pack B").slice(:position, :price, :cards_per_pack, :source_revision))
      .must_equal({ "position" => 2, "price" => 100, "cards_per_pack" => 10, "source_revision" => 11 })
    _(pack("Everything").availability).must_equal({ "regra" => "missao", "missao" => "torneio_slifer_red" })
    _(pack("Pack A").pack_cards.map { |item| [ item.card.name, item.rarity ] }.sort)
      .must_equal [ [ "Clear Wall", "rare" ], [ "Night Assailant", "ultra_rare" ] ]
    _(pack("Flag").cards.pluck(:name).sort).must_equal [ "Clear Wall", "Night Assailant" ]
    _(pack("Everything").cards.count).must_equal 4
  end

  it "grava a banlist e os grupos do conversor, pulando o que não está no pool" do
    importer.run

    _(Banlist.find_by!(name: "Padrão do jogo").entries.map { |entry| [ entry.card.name, entry.status ] })
      .must_equal [ [ "Trap Hole", "limited" ] ]
    _(ConverterGroup.find_by!(amount: 10).cards.pluck(:name).sort).must_equal [ "Ancient Gear", "Trap Hole" ]
    _(ConverterGroup.find_by!(amount: 11).cards.pluck(:engine_code)).must_equal [ 110 ]
  end

  it "pode rodar de novo: mantém os ids e apaga o que saiu dos arquivos" do
    counts = importer.run
    ids = Card.order(:engine_code).pluck(:id)
    Card.create!(engine_code: 999, name: "Velha", source_revision: 1)
    Pack.create!(name: "Velho", position: 99, price: 1, cards_per_pack: 1, source_revision: 1)
    ConverterGroup.create!(amount: 50)

    _(importer.run).must_equal counts
    _(counts).must_equal({ cards: 5, packs: 4, pack_cards: 9, banlist_entries: 1, converter_cards: 3 })
    _(Card.order(:engine_code).pluck(:id)).must_equal ids
    _(ConverterGroup.exists?(amount: 50)).must_equal false
  end
end
