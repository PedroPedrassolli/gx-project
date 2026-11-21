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

  def log_in = post(api_session_path, params: { email: user.email, password: "duelista123" }, as: :json)

  def new_cards = user.collection_cards.where(seen_at: nil).map { |row| row.card.name }.sort

  it "pede login" do
    get api_collection_path

    assert_response :unauthorized
    _(response.parsed_body["error"]["message"]).must_equal "Entre na sua conta para continuar."
  end

  it "devolve as cartas do jogador, com quantidade, data de obtenção e se ainda é nova" do
    post api_session_path, params: { email: user.email, password: "duelista123" }, as: :json
    get api_collection_path

    assert_response :success
    _(response.parsed_body["data"]).must_equal [
      { "card_id" => card("Night Assailant").id, "quantity" => 2, "obtained_at" => "2026-11-08T12:00:00.000-03:00", "new" => true },
      { "card_id" => card("Trap Hole").id, "quantity" => 1, "obtained_at" => "2026-11-09T08:00:00.000-03:00", "new" => true }
    ]
  end

  it "marca como vistas as cartas pedidas, ou todas, e só as do próprio jogador" do
    other = User.create!(email: "syrus@example.com", password: "duelista123", nickname: "Syrus", age_group: "13-17")
    other.collection_cards.create!(card: card("Trap Hole"), quantity: 1, obtained_at: Time.current)
    log_in

    post seen_api_collection_path, params: { card_ids: [ card("Trap Hole").id ] }, as: :json
    assert_response :no_content
    _(new_cards).must_equal [ "Night Assailant" ]
    _(other.collection_cards.first.seen_at).must_be_nil

    post seen_api_collection_path, as: :json
    _(new_cards).must_equal []
  end

  it "lista hostil de cartas vistas não derruba nada: só valem os ids inteiros" do
    log_in

    post seen_api_collection_path, params: { card_ids: { a: "b" } }, as: :json
    assert_response :no_content
    post seen_api_collection_path, params: { card_ids: [ { a: 1 }, "x", nil ] }, as: :json
    assert_response :no_content
    _(new_cards).must_equal [ "Night Assailant", "Trap Hole" ]
    post seen_api_collection_path, params: { card_ids: [ { a: 1 }, card("Trap Hole").id.to_s ] }, as: :json
    _(new_cards).must_equal [ "Night Assailant" ]
  end

  it "a carta ganha depois chega nova, e a que o jogador já tinha não volta a ser nova" do
    user.collection_cards.update_all(seen_at: Time.current)
    CollectionCard.add!(user, { card("Trap Hole").id => 1, card("Clear Wall").id => 1 })

    _(new_cards).must_equal [ "Clear Wall" ]
    _(user.collection_cards.find_by(card: card("Trap Hole")).quantity).must_equal 2
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
