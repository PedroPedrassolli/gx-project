require "test_helper"

class Api::DecksControllerTest < ActionDispatch::IntegrationTest
  include StarterDeckCards

  let(:user) { User.create!(email: "jaden@example.com", password: "duelista123", nickname: "JadenYuki", age_group: "13-17") }
  let(:starter) { user.decks.sole }

  def card(name) = Card.find_by!(name:)
  def row(name, section = "main", quantity = 1, destiny: false) = { card_id: card(name).id, section:, quantity:, destiny: }
  def data = response.parsed_body["data"]

  before do
    load_starter_deck_cards
    Decks::StarterDeck.give_to(user)
    post api_session_path, params: { email: user.email, password: "duelista123" }, as: :json
  end

  it "pede login" do
    delete api_session_path
    get api_decks_path

    assert_response :unauthorized
  end

  it "lista os decks do jogador, com quantas cartas há em cada seção" do
    other = User.create!(email: "syrus@example.com", password: "duelista123", nickname: "Syrus", age_group: "13-17")
    other.decks.create!(name: "Roid")
    get api_decks_path

    assert_response :success
    _(data).must_equal [ { "id" => starter.id, "name" => "Deck inicial", "updated_at" => starter.updated_at.as_json,
                           "counts" => { "main" => 40, "extra" => 0, "side" => 15 } } ]
  end

  it "mostra o deck com as cartas, se é válido e os erros" do
    get api_deck_path(starter)

    _(data["name"]).must_equal "Deck inicial"
    _(data["cards"].size).must_equal starter.deck_cards.count
    _(data["cards"]).must_include({ "card_id" => card("D.D. Assailant").id, "section" => "main", "quantity" => 1, "destiny" => true })
    _(data["valid"]).must_equal true
    _(data["errors"]).must_be_empty
  end

  it "não mostra nem mexe no deck de outro jogador" do
    other = User.create!(email: "syrus@example.com", password: "duelista123", nickname: "Syrus", age_group: "13-17")
    deck = other.decks.create!(name: "Roid")

    get api_deck_path(deck)
    assert_response :not_found
    delete api_deck_path(deck)
    assert_response :not_found
    _(Deck.exists?(deck.id)).must_equal true
  end

  it "salva deck incompleto como rascunho, com os erros, e soma carta repetida na seção" do
    post api_decks_path, params: { name: "Guerreiros", cards: [ row("Armed Ninja"), row("Armed Ninja"), row("Exiled Force", "side") ] }, as: :json

    assert_response :created
    _(data["name"]).must_equal "Guerreiros"
    _(data["cards"]).must_equal [ row("Armed Ninja", "main", 2).stringify_keys, row("Exiled Force", "side").stringify_keys ]
    _(data["valid"]).must_equal false
    _(data["errors"]).must_equal [ "O Main Deck precisa ter de 40 a 60 cartas (tem 2).", "Armed Ninja: você tem 1 e o deck usa 2." ]
  end

  it "recusa nome vazio, seção que não existe, mais de 3 cópias numa linha e carta fora do pool" do
    cards = [ row("Armed Ninja", "baú"), row("Exiled Force", "main", 2), row("Exiled Force", "main", 2),
              { card_id: 0, section: "main", quantity: 1, destiny: false } ]
    post api_decks_path, params: { name: "", cards: }, as: :json

    assert_response :unprocessable_content
    _(response.parsed_body["error"]["fields"]).must_equal({
      "name" => [ "não pode ficar em branco" ],
      "cards" => [ "Armed Ninja: a seção \"baú\" não existe.", "Exiled Force: de 1 a 3 cópias por seção (tem 4).",
                   "A carta 0 não está no pool." ]
    })
    _(user.decks.count).must_equal 1
  end

  it "troca o nome e todas as cartas do deck" do
    patch api_deck_path(starter), params: { name: "Novo nome", cards: [ row("Armed Ninja", "main", 1, destiny: true) ] }, as: :json

    assert_response :success
    _(starter.reload.name).must_equal "Novo nome"
    _(starter.deck_cards.map { |deck_card| [ deck_card.card.name, deck_card.quantity, deck_card.destiny ] }).must_equal [ [ "Armed Ninja", 1, true ] ]
  end

  it "troca só o nome quando as cartas não vêm" do
    patch api_deck_path(starter), params: { name: "Samurais" }, as: :json

    _(starter.reload.name).must_equal "Samurais"
    _(starter.deck_cards.sum(:quantity)).must_equal 55
  end

  it "apaga o deck" do
    delete api_deck_path(starter)

    assert_response :no_content
    _(user.decks.count).must_equal 0
  end

  it "valida sem salvar" do
    cards = starter.deck_cards.map { |deck_card| deck_card.slice(:card_id, :section, :quantity, :destiny) }
    post validate_api_decks_path, params: { cards: }, as: :json

    _(data).must_equal({ "valid" => true, "errors" => [] })

    post validate_api_decks_path, params: { cards: cards.first(1) }, as: :json
    _(data["errors"]).must_equal [ "O Main Deck precisa ter de 40 a 60 cartas (tem 1)." ]
    _(user.decks.count).must_equal 1
  end

  it "para em 50 decks por conta" do
    Deck.insert_all!(49.times.map { |n| { user_id: user.id, name: "Deck #{n}" } })
    post api_decks_path, params: { name: "Mais um", cards: [] }, as: :json

    assert_response :unprocessable_content
    _(response.parsed_body["error"]["message"]).must_equal "Você chegou ao limite de 50 decks."
  end
end
