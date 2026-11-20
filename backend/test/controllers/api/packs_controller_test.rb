require "test_helper"

class Api::PacksControllerTest < ActionDispatch::IntegrationTest
  include CatalogFixture

  before { load_catalog }

  describe "GET /api/packs" do
    it "lista os pacotes na ordem da loja, com quantas cartas têm e sem a regra de liberação" do
      get api_packs_path

      assert_response :success
      packs = response.parsed_body["data"]
      _(packs.pluck("name")).must_equal [ "Pack A", "Pack B", "Flag", "Everything" ]
      _(packs[1].slice("price", "cards_per_pack", "card_count")).must_equal({ "price" => 100, "cards_per_pack" => 10, "card_count" => 1 })
      # A regra fica no servidor: a de código traria o código secreto.
      _(packs.flat_map(&:keys).uniq).wont_include "availability"
      _(response.headers["Cache-Control"]).must_include "s-maxage=3600"
    end

    it "responde 304, sem corpo, quando o navegador já tem a versão atual" do
      get api_packs_path
      get api_packs_path, headers: { "If-None-Match" => response.headers["ETag"] }

      assert_response :not_modified
      _(response.body).must_be_empty
    end
  end
end
