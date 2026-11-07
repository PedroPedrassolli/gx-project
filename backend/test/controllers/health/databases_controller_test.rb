require "test_helper"

class Health::DatabasesControllerTest < ActionDispatch::IntegrationTest
  subject { ActiveRecord::Base.connection }

  # GET /up
  describe "GET /up" do
    it "responde 200 quando o app sobe" do
      get rails_health_check_path
      assert_response :success
    end
  end

  # GET /up/db
  describe "GET #show" do
    it "responde ok quando o banco está no ar" do
      get database_health_check_path
      assert_equal [ 200, "ok" ], [ response.status, response.body ]
    end

    it "responde 503 sem mostrar o erro quando o banco cai" do
      subject.stubs(:select_value).raises(ActiveRecord::ConnectionNotEstablished, "senha errada em db.exemplo")
      get database_health_check_path
      assert_equal [ 503, "banco indisponível" ], [ response.status, response.body ]
    end
  end
end
