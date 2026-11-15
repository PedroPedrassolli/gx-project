require "test_helper"

class Api::RealtimeTokensControllerTest < ActionDispatch::IntegrationTest
  let(:user) { User.create!(email: "jaden@example.com", password: "duelista123", nickname: "JadenYuki", age_group: "13-17") }

  def log_in = post api_session_path, params: { email: user.email, password: "duelista123" }, as: :json
  def data = response.parsed_body["data"]

  # O teste nunca tem a chave de verdade: cada caso põe a sua e tira no fim.
  after { ENV.delete("ABLY_API_KEY") }

  it "pede login" do
    ENV["ABLY_API_KEY"] = "app.chave:segredo"
    post api_realtime_token_path

    assert_response :unauthorized
  end

  it "assina um pedido de token só para o canal do próprio jogador" do
    ENV["ABLY_API_KEY"] = "app.chave:segredo"
    log_in
    post api_realtime_token_path

    assert_response :success
    assert_equal [ "app.chave", user.id.to_s, 3_600_000 ], data.values_at("keyName", "clientId", "ttl")
    assert_equal({ "private:user:#{user.id}" => [ "subscribe" ] }, JSON.parse(data["capability"]))
    assert_predicate data["mac"], :present?
    assert_not_includes response.body, "segredo"
  end

  it "sem a chave, avisa que o tempo real está desligado" do
    log_in
    post api_realtime_token_path

    assert_response :service_unavailable
    assert_equal "O tempo real está desligado.", response.parsed_body.dig("error", "message")
  end
end
