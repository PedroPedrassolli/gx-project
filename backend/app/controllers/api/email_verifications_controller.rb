# Confirmação do e-mail (escopo 3.1). O link do e-mail abre o site, que manda o token aqui.
class Api::EmailVerificationsController < Api::BaseController
  before_action :require_authentication, only: :create

  # POST /api/email_verification: manda o e-mail de confirmação de novo.
  def create
    return render_error(:unprocessable_content, "Seu e-mail já está confirmado.") if current_user.email_verified_at
    unless Accounts::Mailing.deliver(AccountMailer.email_verification(current_user))
      return render_error(:service_unavailable, "Não deu para enviar agora. Tente de novo em alguns minutos.")
    end

    head :accepted
  end

  # PATCH /api/email_verification com { token }. Não pede login: o link pode abrir em
  # outro aparelho.
  def update
    user = User.find_by_token_for(:email_verification, params[:token].to_s)
    return render_error(:unprocessable_content, "Link vencido ou inválido. Peça outro e-mail.") unless user

    user.update!(email_verified_at: Time.current) unless user.email_verified_at
    render json: { user: }
  end
end
