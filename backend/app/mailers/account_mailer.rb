# E-mails da conta. Os links abrem o site, que manda o token para a API.
class AccountMailer < ApplicationMailer
  def email_verification(user)
    @user = user
    @url = "#{Rails.configuration.x.app_url}/verificar-email?token=#{user.generate_token_for(:email_verification)}"
    mail to: user.email, subject: "Confirme seu e-mail no GX Project"
  end
end
