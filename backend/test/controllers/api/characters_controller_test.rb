require "test_helper"

class Api::CharactersControllerTest < ActionDispatch::IntegrationTest
  include StarterDeckCards
  include CharacterCards

  def player(name) = User.create!(email: "#{name.downcase}@example.com", password: "duelista123", nickname: name, age_group: "18+")

  let(:jaden) { player("Jaden") }

  def log_in(user = jaden) = post api_session_path, params: { email: user.email, password: "duelista123" }, as: :json

  def error = response.parsed_body.dig("error", "message")

  it "pede login" do
    get api_characters_path

    assert_response :unauthorized
  end

  it "lista os personagens na ordem: vencido, liberado e bloqueado com a dica" do
    load_character_cards("chumley")
    jaden.character_wins.create!(character: "chumley", wins: 2)
    log_in
    get api_characters_path

    data = response.parsed_body["data"]
    chumley, syrus, blair = data["characters"].first(3)
    assert_equal 14, data["characters"].size
    assert_equal [ "beaten", 2, 60, "Master of Oz", "alunos", "Oz Show" ],
                 [ chumley["status"], chumley["wins"], chumley["bonus"], chumley.dig("signature", "name"), chumley.dig("group", "id"), chumley["deck"] ]
    assert_equal [ "unlocked", nil, nil ], [ syrus["status"], syrus["unlock_hint"], syrus["signature"] ]
    assert_equal [ "locked", "Vença Syrus para liberar." ], blair.values_at("status", "unlock_hint")
    assert_nil data["current_match_id"]
  end

  it "começa o duelo com um deck do jogador e a mesa mostra o personagem" do
    load_starter_deck_cards
    load_character_cards("chumley")
    Decks::StarterDeck.give_to(jaden)
    log_in
    post duels_api_character_path("chumley"), params: { deck_id: jaden.decks.sole.id }, as: :json

    assert_response :created
    match_id = response.parsed_body.dig("data", "match_id")
    get api_characters_path
    assert_equal match_id, response.parsed_body.dig("data", "current_match_id")
    get api_match_path(match_id)
    data = response.parsed_body["data"]
    assert_equal [ "chumley", nil ], data.values_at("character", "room_code")
    assert_equal %w[Chumley Jaden], data["players"].pluck("nickname").sort
  end

  it "recusa o personagem bloqueado, o que não existe e o deck de outro jogador" do
    load_starter_deck_cards
    syrus = player("Syrus")
    Decks::StarterDeck.give_to(syrus)
    Decks::StarterDeck.give_to(jaden)
    log_in

    post duels_api_character_path("syrus"), params: { deck_id: jaden.decks.sole.id }, as: :json
    assert_equal [ 422, "Vença Chumley para liberar Syrus." ], [ response.status, error ]
    post duels_api_character_path("pegasus"), params: { deck_id: jaden.decks.sole.id }, as: :json
    assert_response :not_found
    post duels_api_character_path("chumley"), params: { deck_id: syrus.decks.sole.id }, as: :json
    assert_response :not_found
    # Lista no lugar do id não vira várias buscas (era erro 500).
    post duels_api_character_path("chumley"), params: { deck_id: [ jaden.decks.sole.id ] }, as: :json
    assert_response :not_found
  end
end
