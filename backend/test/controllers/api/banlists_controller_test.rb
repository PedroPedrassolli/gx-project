require "test_helper"

class Api::BanlistsControllerTest < ActionDispatch::IntegrationTest
  include CatalogFixture

  before { load_catalog }

  describe "GET /api/banlists" do
    it "lista as banlists com o status de cada carta" do
      get api_banlists_path

      assert_response :success
      banlist = response.parsed_body["data"].sole
      _(banlist["name"]).must_equal "Padrão do jogo"
      _(banlist["entries"]).must_equal [ { "card_id" => Card.find_by!(engine_code: 200).id, "status" => "limited" } ]
    end
  end
end
