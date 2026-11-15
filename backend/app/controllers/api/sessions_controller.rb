# Quem está logado, entrar e sair (ADR 0008).
class Api::SessionsController < Api::BaseController
  # GET /api/session: o usuário (ou null), o token CSRF, que o front manda no cabeçalho
  # X-CSRF-Token em todo pedido que muda algo, e o duelo em andamento, para a volta à mesa
  # de qualquer página (escopo 3.7, reconexão).
  def show
    render json: { user: current_user, csrf_token: form_authenticity_token, duel: current_duel }
  end

  # POST /api/session. A resposta não conta se o erro foi no e-mail ou na senha.
  def create
    user = User.authenticate_by(email: params[:email].to_s, password: params[:password].to_s)
    return render_error(:unauthorized, "E-mail ou senha incorretos.") unless user

    start_new_session_for(user)
    render json: { user: }, status: :created
  end

  # DELETE /api/session
  def destroy
    terminate_session if current_user
    head :no_content
  end

  private

  def current_duel
    match = current_user && Match.current_for(current_user)
    { match_id: match.id, room_code: match.room.code } if match
  end
end
