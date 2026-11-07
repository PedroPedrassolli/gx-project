require "test_helper"

class Health::EnginesControllerTest < ActionDispatch::IntegrationTest
  subject { Duel::HealthCheck }

  # GET /up/engine
  describe "GET #show" do
    it "responde 200 com a primeira pergunta do duelo" do
      get engine_health_check_path
      assert_equal [ 200, "select_chain" ], [ response.status, response.parsed_body["first_prompt"] ]
    end

    it "responde 503 quando a engine falha" do
      subject.stubs(:run).returns({ ok: false, error: "sem biblioteca" })
      get engine_health_check_path
      assert_equal [ 503, "sem biblioteca" ], [ response.status, response.parsed_body["error"] ]
    end
  end
end
