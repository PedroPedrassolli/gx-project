require "test_helper"

class Api::CollectionsControllerTest < ActionDispatch::IntegrationTest
  include CatalogFixture

  let(:user) { User.create!(email: "jaden@example.com", password: "duelista123", nickname: "JadenYuki", age_group: "13-17") }

  def card(name) = Card.find_by!(name:)

  before do
    load_catalog
    user.collection_cards.create!(card: card("Night Assailant"), quantity: 2, obtained_at: Time.zone.local(2026, 11, 8, 12))
    user.collection_cards.create!(card: card("Trap Hole"), quantity: 1, obtained_at: Time.zone.local(2026, 11, 9, 8))
  end

  it "pede login" do
    get api_collection_path

    assert_response :unauthorized
    _(response.parsed_body["error"]["message"]).must_equal "Entre na sua conta para continuar."
  end

  it "devolve as cartas do jogador, com quantidade e data de obtenção" do
    post api_session_path, params: { email: user.email, password: "duelista123" }, as: :json
    get api_collection_path

    assert_response :success
    _(response.parsed_body["data"]).must_equal [
      { "card_id" => card("Night Assailant").id, "quantity" => 2, "obtained_at" => "2026-11-08T12:00:00.000-03:00" },
      { "card_id" => card("Trap Hole").id, "quantity" => 1, "obtained_at" => "2026-11-09T08:00:00.000-03:00" }
    ]
  end

  it "conta quanto do pool e de cada pacote o jogador já tem" do
    post api_session_path, params: { email: user.email, password: "duelista123" }, as: :json
    get api_collection_path

    meta = response.parsed_body["meta"]
    _(meta["total"]).must_equal({ "owned" => 2, "cards" => 5, "percent" => 40.0 })
    _(meta["packs"].map { |pack| [ Pack.find(pack["id"]).name, pack["owned"], pack["cards"], pack["percent"] ] }).must_equal [
      [ "Pack A", 1, 2, 50.0 ], [ "Pack B", 1, 1, 100.0 ], [ "Flag", 1, 2, 50.0 ], [ "Everything", 2, 4, 50.0 ]
    ]
  end
end
