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

  it "compra com entrada hostil responde o erro certo, nunca 500, e não cobra nada" do
    Economy::Ledger.post!(user, 300, reason: "duel", key: "partida:1")

    post purchases_api_shop_path, params: { pack_id: pack_a.id, count: { a: 1 }, key: "compra-0001" }, as: :json
    assert_response :unprocessable_content
    post purchases_api_shop_path, params: { pack_id: [ pack_a.id ], count: 1, key: "compra-0002" }, as: :json
    assert_response :not_found
    assert_equal 300, Economy::Ledger.balance(user)
  end

  it "a prateleira traz o saldo, o nível e cada pacote, com a dica dos bloqueados" do
    Economy::Ledger.post!(user, 300, reason: "duel", key: "partida:1")
    get api_shop_path

    data = response.parsed_body["data"]
    assert_equal [ 300, 1 ], data.values_at("balance", "level")
    assert_equal({ "id" => pack_a.id, "name" => "Pack A", "price" => 50, "cards_per_pack" => 5, "available" => true, "hint" => nil, "new" => true },
                 data["packs"].first)
    assert_equal [ false, "Chegue ao nível 10.", false ], data["packs"].second.values_at("available", "hint", "new")
  end

  it "o pacote liberado aparece como novo até o jogador ver a prateleira" do
    post seen_api_shop_path, as: :json
    assert_response :no_content
    assert_equal [ pack_a.id ], user.reload.seen_pack_ids

    get api_shop_path
    assert_equal [ false ], response.parsed_body.dig("data", "packs").pluck("new").uniq
    user.update!(level: 10)
    get api_shop_path
    assert_equal [ "Pack B" ], response.parsed_body.dig("data", "packs").select { |pack| pack["new"] }.pluck("name")
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

  describe "conversor" do
    let(:trap_hole) { Card.find_by!(name: "Trap Hole") }
    let(:assailant) { Card.find_by!(name: "Night Assailant") }

    before { CollectionCard.add!(user, { trap_hole.id => 8, assailant.id => 6 }) }

    def convert(cards, key: "conversao-0001") = post(conversions_api_shop_path, params: { cards:, key: }, as: :json)

    it "mostra as repetidas e as cartas do grupo de uma quantidade" do
      get converter_api_shop_path

      data = response.parsed_body["data"]
      assert_equal [ 10, 99 ], data.values_at("min", "max")
      assert_equal [ { "card_id" => trap_hole.id, "quantity" => 7 }, { "card_id" => assailant.id, "quantity" => 5 } ], data["cards"].sort_by { |card| -card["quantity"] }

      get converter_group_api_shop_path(10)
      assert_equal Card.where(name: [ "Trap Hole", "Ancient Gear" ]).order(:id).ids, response.parsed_body.dig("data", "cards")
      get converter_group_api_shop_path(12)
      assert_response :not_found
    end

    it "converte: 201 com a carta, e a mesma chave devolve a mesma carta" do
      convert([ { id: trap_hole.id, quantity: 6 }, { id: assailant.id, quantity: 3 }, { id: assailant.id, quantity: 2 } ])

      assert_response :created
      data = response.parsed_body["data"]
      assert_equal [ assailant.id, 11, false ], data.values_at("card_id", "amount", "new")
      convert([ { id: trap_hole.id, quantity: 6 }, { id: assailant.id, quantity: 5 } ])
      assert_equal [ 201, data ], [ response.status, response.parsed_body["data"] ]
      assert_equal 1, user.card_conversions.count
    end

    it "recusa pedido fora do formato e cartas que não dá para converter" do
      convert([ { id: trap_hole.id, quantity: 10 } ], key: "x")
      assert_equal [ 422, "Pedido inválido." ], [ response.status, response.parsed_body.dig("error", "message") ]
      convert("tudo")
      assert_equal [ 422, "Escolha de 10 a 99 cartas." ], [ response.status, response.parsed_body.dig("error", "message") ]
      convert([ { id: trap_hole.id, quantity: 8 }, { id: assailant.id, quantity: 2 } ])
      assert_equal 422, response.status
      assert_equal 0, user.card_conversions.count
    end
  end
end
