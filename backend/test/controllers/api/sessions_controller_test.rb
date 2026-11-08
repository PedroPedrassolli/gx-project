require "test_helper"

class Api::SessionsControllerTest < ActionDispatch::IntegrationTest
  let(:user) { User.create!(email: "jaden@example.com", password: "duelista123", nickname: "JadenYuki", age_group: "13-17") }

  before { user }

  def log_in(email: user.email, password: "duelista123")
    post api_session_path, params: { email:, password: }, as: :json
  end

  describe "GET /api/session" do
    it "sem login, devolve usuário nulo e o token CSRF" do
      get api_session_path

      assert_response :success
      _(response.parsed_body["user"]).must_be_nil
      _(response.parsed_body["csrf_token"]).wont_be_empty
    end

    it "com login, devolve o usuário, sem a senha" do
      log_in
      get api_session_path

      _(response.parsed_body["user"]).must_equal({ "id" => user.id, "email" => "jaden@example.com", "email_verified" => false,
                                                   "nickname" => "JadenYuki", "age_group" => "13-17", "role" => "player" })
    end
  end

  describe "POST /api/session" do
    it "entra com e-mail e senha, sem diferenciar maiúsculas no e-mail" do
      log_in(email: " JADEN@example.com")

      assert_response :created
      _(response.parsed_body["user"]["nickname"]).must_equal "JadenYuki"
      _(user.sessions.count).must_equal 1
      _(Array(response.headers["Set-Cookie"]).join("\n")).must_match(/session_id=.*; httponly; samesite=lax/i)
    end

    it "não conta se o erro foi no e-mail ou na senha" do
      log_in(password: "errada123")
      wrong_password = response.parsed_body

      log_in(email: "ninguem@example.com")

      assert_response :unauthorized
      _(response.parsed_body).must_equal wrong_password
      _(response.parsed_body["error"]["message"]).must_equal "E-mail ou senha incorretos."
    end
  end

  describe "DELETE /api/session" do
    it "sai: apaga a sessão e o cookie" do
      log_in
      delete api_session_path

      assert_response :no_content
      _(Session.count).must_equal 0
      get api_session_path
      _(response.parsed_body["user"]).must_be_nil
    end

    it "sem login, não faz nada" do
      delete api_session_path

      assert_response :no_content
    end
  end

  describe "CSRF" do
    before { Api::BaseController.allow_forgery_protection = true }
    after { Api::BaseController.allow_forgery_protection = false }

    it "recusa pedido que muda algo sem o token" do
      log_in

      assert_response :forbidden
      _(response.parsed_body["error"]["message"]).must_equal "A página ficou velha. Recarregue e tente de novo."
    end

    it "aceita com o token que veio em GET /api/session" do
      get api_session_path
      token = response.parsed_body["csrf_token"]
      post api_session_path, params: { email: user.email, password: "duelista123" }, headers: { "X-CSRF-Token" => token }, as: :json

      assert_response :created
    end

    it "não cria cookie nas rotas do catálogo, que a CDN guarda" do
      get api_packs_path

      _(response.headers["Set-Cookie"]).must_be_nil
    end
  end
end
