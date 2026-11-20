require "test_helper"

class Api::ShopControllerTest < ActionDispatch::IntegrationTest
  include CatalogFixture

  let(:user) { User.create!(email: "jaden@example.com", password: "duelista123", nickname: "JadenYuki", age_group: "18+") }
  let(:pack_a) { Pack.find_by!(name: "Pack A") }

  before do
    load_catalog
    post api_session_path, params: { email: user.email, password: "duelista123" }, as: :json
  end

  def buy(count: 1, key: "compra-0001", pack: pack_a) = post(purchases_api_shop_path, params: { pack_id: pack.id, count:, key: }, as: :json)

  it "a prateleira traz o saldo, o nível e cada pacote, com a dica dos bloqueados" do
    Economy::Ledger.post!(user, 300, reason: "duel", key: "partida:1")
    get api_shop_path

    data = response.parsed_body["data"]
    assert_equal [ 300, 1 ], data.values_at("balance", "level")
    assert_equal({ "id" => pack_a.id, "name" => "Pack A", "price" => 50, "cards_per_pack" => 5, "available" => true, "hint" => nil }, data["packs"].first)
    assert_equal [ false, "Chegue ao nível 10." ], data["packs"].second.values_at("available", "hint")
  end

  it "a compra cobra, sorteia, guarda a abertura e põe as cartas na coleção; a mesma chave não cobra de novo" do
    Economy::Ledger.post!(user, 600, reason: "duel", key: "partida:1")
    buy(count: 10)

    assert_equal 201, response.status
    openings = response.parsed_body.dig("data", "openings")
    assert_equal [ 100, 10, [ 5 ] ], [ response.parsed_body.dig("data", "balance"), openings.size, openings.map(&:size).uniq ]
    cards = openings.flatten
    assert_empty cards.pluck("id") - pack_a.pack_cards.pluck(:card_id)
    assert_equal cards.pluck("id").uniq.size, cards.count { |card| card["new"] }
    assert_equal cards.size, user.collection_cards.sum(:quantity)
    assert_equal 10, user.pack_openings.count

    buy(count: 10)
    assert_equal [ 201, 100, 10 ], [ response.status, response.parsed_body.dig("data", "balance"), user.pack_openings.count ]
  end

  it "recusa sem DP, pacote bloqueado e pedido fora do formato" do
    buy
    assert_equal [ 422, "DP insuficiente para esta compra." ], [ response.status, response.parsed_body.dig("error", "message") ]

    Economy::Ledger.post!(user, 600, reason: "duel", key: "partida:1")
    buy(pack: Pack.find_by!(name: "Pack B"))
    assert_equal [ 422, "Este pacote ainda não está liberado para você." ], [ response.status, response.parsed_body.dig("error", "message") ]

    buy(count: 3)
    assert_equal [ 422, "Compre 1 ou 10 pacotes." ], [ response.status, response.parsed_body.dig("error", "message") ]
    buy(key: "x")
    assert_equal 422, response.status
    assert_equal [ 600, 0 ], [ Economy::Ledger.balance(user), user.pack_openings.count ]
  end

  it "o código secreto libera o pacote; código errado tem sempre a mesma resposta" do
    pack = Pack.find_by!(name: "Pack B")
    pack.update!(availability: { "regra" => "qualquer", "regras" => [ { "regra" => "nivel", "nivel" => 10 }, { "regra" => "codigo", "codigo" => "↑ ↑ ↓ ↓" } ] })
    post codes_api_shop_path, params: { code: "↓↓↑↑" }, as: :json
    assert_equal [ 422, "Esse código não libera nada." ], [ response.status, response.parsed_body.dig("error", "message") ]
    post codes_api_shop_path, params: {}, as: :json
    assert_equal [ 422, 0 ], [ response.status, user.code_unlocks.count ]

    2.times { post codes_api_shop_path, params: { code: " ↑↑ ↓↓ " }, as: :json }
    assert_equal [ 201, [ "Pack B" ], [ "↑↑↓↓" ] ], [ response.status, response.parsed_body.dig("data", "packs"), user.code_unlocks.pluck(:code) ]
    get api_shop_path
    assert_equal [ true, nil ], response.parsed_body.dig("data", "packs").second.values_at("available", "hint")
  end

  it "o pacote de missão libera para quem concluiu a missão" do
    get api_shop_path
    assert_equal [ false, "Conclua a missão Torneio Slifer Red." ], response.parsed_body.dig("data", "packs").last.values_at("available", "hint")

    user.mission_completions.create!(mission: "torneio_slifer_red", period: "once")
    get api_shop_path
    assert_equal true, response.parsed_body.dig("data", "packs").last["available"]
  end

  it "sem login, nada" do
    delete api_session_path, as: :json
    get api_shop_path

    assert_equal 401, response.status
  end
end
