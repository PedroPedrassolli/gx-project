require "test_helper"

class Api::CardsControllerTest < ActionDispatch::IntegrationTest
  include CatalogFixture

  before { load_catalog }

  def data = response.parsed_body["data"]
  def names(query = {}) = get(api_cards_path, params: query).then { data.pluck("name") }
  def card_id(code) = Card.find_by!(engine_code: code).id

  describe "GET /api/cards" do
    it "lista todas as cartas pelo nome, sem os campos vazios" do
      get api_cards_path

      assert_response :success
      _(data.pluck("name")).must_equal [ "Ancient Gear", "Clear Wall", "Cyril", "Night Assailant", "Trap Hole" ]
      _(response.parsed_body["meta"]["total"]).must_equal 5
      _(data.last).must_equal({ "id" => card_id(200), "name" => "Trap Hole", "card_type" => "Trap",
                                "property" => "Normal", "banlist" => "limited" })
    end

    it "busca pelo nome em inglês ou em português, sem acento e sem caixa" do
      _(names(q: "assaltante")).must_equal [ "Night Assailant" ]
      _(names(q: "NOTURNO")).must_equal [ "Night Assailant" ]
      _(names(q: "cyr")).must_equal [ "Cyril" ]
    end

    it "filtra por tipo, propriedade, atributo, raça, tipo de monstro e nível" do
      _(names(card_type: "trap")).must_equal [ "Trap Hole" ]
      _(names(property: "normal")).must_equal [ "Trap Hole" ]
      _(names(attribute: "LIGHT")).must_equal [ "Cyril" ]
      _(names(race: "fiend", monster_type: "flip", level: "3")).must_equal [ "Night Assailant" ]
      _(names(card_type: "dragão")).must_equal []
    end

    it "filtra pela faixa de ATK e DEF, deixando de fora quem não tem o valor" do
      _(names(atk_min: "100")).must_equal [ "Night Assailant" ]
      _(names(def_max: "500")).must_equal [ "Night Assailant" ]
      _(names(atk_min: "300")).must_equal []
    end

    it "filtra por pacote e mostra a raridade nele" do
      get api_cards_path, params: { pack: Pack.find_by!(name: "Pack A").id }

      _(data.map { |card| card.values_at("name", "rarity") }).must_equal [ [ "Clear Wall", "rare" ], [ "Night Assailant", "ultra_rare" ] ]
    end

    it "ordena pelo campo pedido, com quem não tem o valor no fim" do
      _(names(sort: "level", order: "desc")).must_equal [ "Cyril", "Night Assailant", "Ancient Gear", "Clear Wall", "Trap Hole" ]
      _(names(sort: "type")).must_equal [ "Cyril", "Night Assailant", "Trap Hole", "Ancient Gear", "Clear Wall" ]
    end
  end

  describe "GET /api/cards/:id" do
    it "mostra a carta inteira, com os textos, os pacotes e a fonte" do
      get api_card_path(card_id(110))

      assert_response :success
      _(data.slice("name", "passcode", "text", "banlist")).must_equal({ "name" => "Night Assailant", "passcode" => 100,
                                                                         "text" => "FLIP: Destroy 1 monster." })
      _(data["packs"].pluck("rarity").sort).must_equal %w[ultra_rare ultra_rare ultra_rare]
      _(data["source"]).must_equal "https://yugipedia.com/index.php?oldid=1"
    end

    it "responde 404 em JSON para carta que não existe" do
      get api_card_path(0)

      assert_response :not_found
      _(response.parsed_body["error"]["status"]).must_equal 404
      get api_card_path("abc")
      assert_response :not_found
    end
  end

  describe "cache" do
    it "deixa a CDN guardar e responde 304 quando nada mudou" do
      get api_cards_path, params: { q: "trap" }
      etag = response.headers["ETag"]

      _(response.headers["Cache-Control"].split(", ")).must_include "s-maxage=3600"
      _(response.headers["Cache-Control"]).must_include "stale-while-revalidate=86400"
      _(response.headers["Cache-Control"]).must_include "public"
      get api_cards_path, params: { q: "trap" }, headers: { "If-None-Match" => etag }
      assert_response :not_modified
      get api_cards_path, params: { q: "hole" }, headers: { "If-None-Match" => etag }
      assert_response :success
    end
  end
end
