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
      _(file["account"].keys).must_equal %w[email email_verified_at nickname age_group role terms_accepted_at created_at level dp_earned]
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

    it "traz também o DP, os pacotes, as partidas, os desafios, as missões, os códigos e as conversões (F4)" do
      card = Card.find_by!(name: "D.D. Assailant")
      pack = Pack.create!(name: "Pacote de teste", position: 99, price: 50, cards_per_pack: 1, source_revision: 1)
      Economy::Ledger.post!(user, 100, reason: "duel", key: "teste:1", note: "duelo")
      user.pack_openings.create!(pack:, purchase_key: "k1", position: 0, seed: 1, cards: [ { id: card.id, rarity: "common", new: true } ])
      match = Match.create!(mode: "1x1", banlist: true, destiny_draw: false, seed: [ 1, 2, 3, 4 ], started_at: Time.current,
                            status: "finished", winner_team: 0, finished_at: Time.current)
      match.players.create!(team: 0, seat: 0, user:, deck: { main: [], extra: [] }, rewards: { total: 42 })
      user.user_challenges.create!(number: 26, match:)
      user.mission_completions.create!(mission: "carta_da_semana", period: "2026-W46", card:, match:)
      user.code_unlocks.create!(code: "↑↑↓↓")
      user.card_conversions.create!(key: "c1", amount: 10, spent: { card.id => 10 }, seed: 1, card:, new_card: false)
      user.character_wins.create!(character: "chumley", wins: 3)
      user.character_wins.create!(character: "gx-antigo", wins: 1)
      log_in

      get export_api_me_path

      file = JSON.parse(response.body)
      _(file["dp"].map { |row| row.slice("amount", "balance_after", "reason") }).must_equal [ { "amount" => 100, "balance_after" => 100, "reason" => "duel" } ]
      _(file["pack_openings"].map { |row| row.slice("pack", "cards") }).must_equal [ { "pack" => "Pacote de teste", "cards" => [ "D.D. Assailant" ] } ]
      _(file["matches"].map { |row| row.slice("result", "dp") }).must_equal [ { "result" => "vitória", "dp" => 42 } ]
      _(file["challenges"].map { |row| row.slice("number", "label") }).must_equal [ { "number" => 26, "label" => "Empatar um duelo" } ]
      _(file["missions"].map { |row| row.slice("mission", "period", "card") }).must_equal [ { "mission" => "Carta da semana", "period" => "2026-W46", "card" => "D.D. Assailant" } ]
      _(file["secret_codes"].map { |row| row["code"] }).must_equal [ "↑↑↓↓" ]
      _(file["conversions"].map { |row| row.slice("spent", "card") }).must_equal [ { "spent" => { "D.D. Assailant" => 10 }, "card" => "D.D. Assailant" } ]
      _(file["characters"].map { |row| row.slice("character", "wins") }).must_equal [ { "character" => "Chumley", "wins" => 3 }, { "character" => "gx-antigo", "wins" => 1 } ]
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
