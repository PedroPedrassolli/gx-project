require "test_helper"

# Importar e exportar decks (ADR 0009).
class Api::DeckFilesTest < ActionDispatch::IntegrationTest
  include StarterDeckCards

  let(:user) { User.create!(email: "jaden@example.com", password: "duelista123", nickname: "JadenYuki", age_group: "13-17") }
  let(:starter) { user.decks.sole }

  def card(name) = Card.find_by!(name:)
  def data = response.parsed_body["data"]
  def import(content, kind:, name: "Importado") = post(import_api_decks_path, params: { name:, kind:, content: }, as: :json)
  def rows(deck) = deck.deck_cards.order(:id).map { |row| [ row.card.name, row.section, row.quantity, row.destiny ] }

  before do
    load_starter_deck_cards
    Decks::StarterDeck.give_to(user)
    post api_session_path, params: { email: user.email, password: "duelista123" }, as: :json
  end

  it "importa .ydk: pula carta fora do pool e corta em 3 cópias, avisando" do
    ninja = card("Armed Ninja").passcode
    import "#main\n#{ninja}\n#{ninja}\n#{ninja}\n#{ninja}\n12345\n!side\n#{card("Millennium Shield").passcode}\n", kind: "ydk"

    assert_response :created
    _(rows(user.decks.find(data["id"]))).must_equal [ [ "Armed Ninja", "main", 3, false ], [ "Millennium Shield", "side", 1, false ] ]
    _(response.parsed_body["meta"]["warnings"]).must_equal [ "O código 12345 não está no pool.",
                                                             "Armed Ninja: o arquivo tinha 4 cópias; ficaram 3." ]
    _(data["valid"]).must_equal false
  end

  it "importa texto com nome em português ou inglês, sem diferenciar maiúsculas" do
    card("Armed Ninja").update!(name_pt: "Ninja Armado")
    import "Main Deck\n2 NINJA ARMADO\n1 d.d. assailant (Destiny)\nSó texto\n1 Carta Inventada\n", kind: "text", name: ""

    assert_response :created
    _(data["name"]).must_equal "Deck importado"
    _(rows(user.decks.find(data["id"]))).must_equal [ [ "Armed Ninja", "main", 2, false ], [ "D.D. Assailant", "main", 1, true ] ]
    _(response.parsed_body["meta"]["warnings"]).must_equal [ "Linha 4: não entendi \"Só texto\".",
                                                             "\"Carta Inventada\" não está no pool." ]
  end

  it "não cria deck quando nada do arquivo está no pool, nem com formato desconhecido" do
    import "#main\n12345\n", kind: "ydk"
    assert_response :unprocessable_content
    _(response.parsed_body["error"]["message"]).must_equal "Nenhuma carta do arquivo está no pool."

    import "qualquer coisa", kind: "pdf"
    _(response.parsed_body["error"]["message"]).must_equal "Formato desconhecido: use ydk ou text."
    _(user.decks.count).must_equal 1
  end

  it "recusa arquivo maior que 50 KB" do
    import "#main\n#{"1234567\n" * 7_000}", kind: "ydk"

    assert_response :unprocessable_content
    _(response.parsed_body["error"]["message"]).must_equal "Arquivo grande demais: o limite é 50 KB."
  end

  it "respeita o limite de decks ao importar" do
    Deck.insert_all!(49.times.map { |n| { user_id: user.id, name: "Deck #{n}" } })
    import "1 Armed Ninja", kind: "text"

    _(response.parsed_body["error"]["message"]).must_equal "Você chegou ao limite de 50 decks."
  end

  it "exporta .ydk, com os códigos de cada cópia" do
    get export_api_deck_path(starter, format: :ydk)

    assert_response :success
    _(response.headers["Content-Disposition"]).must_include "filename=\"Deck inicial.ydk\""
    _(response.body.lines.first(2)).must_equal [ "#created by GX Project\n", "#main\n" ]
    _(response.body.lines.count { |line| line.match?(/\A\d+\n\z/) }).must_equal 55
    _(Decks::Ydk.parse(response.body).sum { |row| row[:quantity] }).must_equal 55
  end

  it "exporta texto, com as Destiny marcadas, e o import lê de volta igual" do
    get export_api_deck_path(starter, format: :txt)

    _(response.headers["Content-Disposition"]).must_include "filename=\"Deck inicial.txt\""
    _(response.body).must_include "1 D.D. Assailant (Destiny)\n"

    import response.body, kind: "text"
    _(rows(user.decks.find(data["id"]))).must_equal rows(starter)
  end

  it "não exporta em formato desconhecido" do
    get export_api_deck_path(starter, format: :pdf)

    assert_response :not_found
  end
end
