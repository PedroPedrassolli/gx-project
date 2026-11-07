require "test_helper"

class Health::EnginesControllerTest < ActionDispatch::IntegrationTest
  subject { Duel::HealthCheck }

  # GET /up/engine
  describe "GET #show" do
    it "responde 200 depois de refazer o duelo gravado" do
      get engine_health_check_path
      assert_equal [ 200, true, 1 ], [ response.status, *response.parsed_body.values_at("ok", "winner") ]
    end

    it "responde 503 quando a engine falha" do
      subject.stubs(:run).returns({ ok: false, error: "sem biblioteca" })
      get engine_health_check_path
      assert_equal [ 503, "sem biblioteca" ], [ response.status, response.parsed_body["error"] ]
    end
  end
end
