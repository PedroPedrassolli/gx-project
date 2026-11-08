require "test_helper"

# Direitos da LGPD sobre a própria conta: baixar os dados e excluir a conta (GXP-36).
class Api::MeControllerTest < ActionDispatch::IntegrationTest
  include StarterDeckCards

  let(:user) { User.create!(email: "jaden@example.com", password: "duelista123", nickname: "JadenYuki", age_group: "13-17") }

  def log_in = post(api_session_path, params: { email: user.email, password: "duelista123" }, as: :json)

  before do
    load_starter_deck_cards
    Decks::StarterDeck.give_to(user)
  end

  describe "GET /api/me/export" do
    it "pede login" do
      get export_api_me_path

      assert_response :unauthorized
    end

    it "baixa um JSON com a conta, as sessões, a coleção e os decks, sem a senha" do
      other = User.create!(email: "syrus@example.com", password: "duelista123", nickname: "Syrus", age_group: "13-17")
      other.decks.create!(name: "Roid")
      log_in

      travel_to Time.zone.local(2026, 11, 8, 12) do
        get export_api_me_path
      end

      assert_response :success
      _(response.headers["Content-Disposition"]).must_include "filename=\"gx-project-meus-dados.json\""
      file = JSON.parse(response.body)
      _(file["exported_at"]).must_equal "2026-11-08T12:00:00.000-03:00"
      _(file["account"].keys).must_equal %w[email nickname age_group role created_at]
      _(file["account"]["email"]).must_equal "jaden@example.com"
      _(file["sessions"].size).must_equal 1
      _(file["collection"].sum { |card| card["quantity"] }).must_equal 55
      _(file["collection"]).must_include({ "card" => "Warrior Lady of the Wasteland", "quantity" => 2,
                                           "obtained_at" => user.collection_cards.first.obtained_at.as_json })
      _(file["decks"].map { |deck| deck["name"] }).must_equal [ "Deck inicial" ]
      _(file["decks"].first["cards"]).must_include({ "card" => "D.D. Assailant", "section" => "main", "quantity" => 1, "destiny" => true })
      _(response.body).wont_include "password"
      _(response.body).wont_include "Syrus"
    end
  end

  describe "DELETE /api/me" do
    it "não apaga com a senha errada" do
      log_in
      delete api_me_path, params: { password: "errada123" }, as: :json

      assert_response :unprocessable_content
      _(response.parsed_body["error"]["fields"]).must_equal({ "password" => [ "não confere" ] })
      _(User.exists?(user.id)).must_equal true
    end

    it "apaga a conta e tudo dela, e sai" do
      log_in
      delete api_me_path, params: { password: "duelista123" }, as: :json

      assert_response :no_content
      _([ User.count, Session.count, Deck.count, DeckCard.count, CollectionCard.count ]).must_equal [ 0, 0, 0, 0, 0 ]
      get api_session_path
      _(response.parsed_body["user"]).must_be_nil
    end
  end
end
