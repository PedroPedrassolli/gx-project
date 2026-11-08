require "test_helper"

class Api::PasswordsControllerTest < ActionDispatch::IntegrationTest
  let(:user) { User.create!(email: "jaden@example.com", password: "duelista123", nickname: "JadenYuki", age_group: "13-17") }

  before { user }

  def ask(email) = post(api_password_path, params: { email: }, as: :json)
  def reset(token, password) = patch(api_password_path, params: { token:, password: }, as: :json)
  def log_in(password) = post(api_session_path, params: { email: user.email, password: }, as: :json)

  describe "POST /api/password" do
    it "manda o link para a conta, e responde igual quando o e-mail não tem conta" do
      assert_emails(1) { ask " JADEN@example.com" }
      assert_response :accepted

      assert_no_emails { ask "ninguem@example.com" }
      assert_response :accepted
    end
  end

  describe "PATCH /api/password" do
    it "troca a senha, sai de todos os aparelhos e o link não vale de novo" do
      log_in "duelista123"
      token = user.password_reset_token

      reset token, "novasenha123"

      assert_response :success
      _(user.sessions.count).must_equal 0
      log_in "novasenha123"
      assert_response :created

      reset token, "outrasenha123"
      assert_response :unprocessable_content
    end

    it "recusa link inválido ou vencido" do
      token = user.password_reset_token

      reset "abc", "novasenha123"
      _(response.parsed_body["error"]["message"]).must_equal "Link vencido ou inválido. Peça outro e-mail."

      travel(2.hours) { reset token, "novasenha123" }
      assert_response :unprocessable_content
    end

    it "pede senha nova válida" do
      reset user.password_reset_token, "123"
      _(response.parsed_body["error"]["fields"]).must_equal({ "password" => [ "é curta demais (mínimo de 8 caracteres)" ] })

      reset user.password_reset_token, ""
      _(response.parsed_body["error"]["fields"]).must_equal({ "password" => [ "não pode ficar em branco" ] })
    end
  end
end
