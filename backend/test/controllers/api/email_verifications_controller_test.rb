require "test_helper"

class Api::EmailVerificationsControllerTest < ActionDispatch::IntegrationTest
  let(:user) { User.create!(email: "jaden@example.com", password: "duelista123", nickname: "JadenYuki", age_group: "13-17") }

  def log_in = post(api_session_path, params: { email: user.email, password: "duelista123" }, as: :json)
  def confirm(token) = patch(api_email_verification_path, params: { token: }, as: :json)

  describe "POST /api/email_verification" do
    it "pede login" do
      post api_email_verification_path

      assert_response :unauthorized
    end

    it "manda o e-mail de novo" do
      log_in

      assert_emails(1) { post api_email_verification_path }
      assert_response :accepted
    end

    it "não manda para quem já confirmou" do
      user.update!(email_verified_at: Time.current)
      log_in

      assert_no_emails { post api_email_verification_path }
      _(response.parsed_body["error"]["message"]).must_equal "Seu e-mail já está confirmado."
    end

    it "avisa quando o envio falha" do
      log_in
      ActionMailer::MessageDelivery.any_instance.stubs(:deliver_now).raises(Net::SMTPAuthenticationError, "535")

      post api_email_verification_path

      assert_response :service_unavailable
      _(response.parsed_body["error"]["message"]).must_equal "Não deu para enviar agora. Tente de novo em alguns minutos."
    end
  end

  describe "PATCH /api/email_verification" do
    it "confirma o e-mail com o token do link, sem pedir login" do
      travel_to Time.zone.local(2026, 11, 8, 12) do
        confirm user.generate_token_for(:email_verification)
      end

      assert_response :success
      _(response.parsed_body["user"]["email_verified"]).must_equal true
      _(user.reload.email_verified_at).must_equal Time.zone.local(2026, 11, 8, 12)
    end

    it "recusa token inválido, vencido ou de um e-mail que mudou" do
      token = user.generate_token_for(:email_verification)

      confirm "abc"
      _(response.parsed_body["error"]["message"]).must_equal "Link vencido ou inválido. Peça outro e-mail."

      travel(3.days) { confirm token }
      assert_response :unprocessable_content

      user.update!(email: "outro@example.com")
      confirm token
      assert_response :unprocessable_content
      _(user.reload.email_verified_at).must_be_nil
    end
  end
end
