# Esqueci a senha (escopo 3.1). O link do e-mail abre o site, que manda o token e a senha
# nova para cá.
class Api::PasswordsController < Api::BaseController
  # POST /api/password com { email }: manda o link, se o e-mail tiver conta. A resposta é
  # sempre a mesma, para não contar a ninguém quem tem conta.
  def create
    user = User.find_by(email: params[:email].to_s)
    Accounts::Mailing.deliver(AccountMailer.password_reset(user)) if user
    head :accepted
  end

  # PATCH /api/password com { token, password }: troca a senha e sai de todos os aparelhos.
  def update
    user = User.find_by_password_reset_token(params[:token].to_s)
    return render_error(:unprocessable_content, "Link vencido ou inválido. Peça outro e-mail.") unless user
    return render_error(:unprocessable_content, "Confira a senha.", user.errors.to_hash) unless user.update(password: params[:password].to_s.presence)

    user.sessions.destroy_all
    render json: { user: }
  end
end
