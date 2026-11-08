# Login por cookie (ADR 0008), como o gerador de autenticação do Rails 8, só que em JSON.
module Authentication
  extend ActiveSupport::Concern

  private

  def current_user
    Current.session ||= find_session_by_cookie
    Current.user
  end

  # Para controller que exige login: `before_action :require_authentication`.
  def require_authentication
    render_error(:unauthorized, "Entre na sua conta para continuar.") unless current_user
  end

  def find_session_by_cookie
    Session.active.find_by(id: cookies.signed[:session_id]) if cookies.signed[:session_id]
  end

  # Entrar troca a sessão do Rails, que só guarda o token CSRF: o token de antes do login
  # deixa de valer. Aproveita para apagar os logins vencidos da conta.
  def start_new_session_for(user)
    reset_session
    user.sessions.expired.delete_all
    Current.session = user.sessions.create!
    cookies.signed[:session_id] = {
      value: Current.session.id, expires: Session::DURATION.from_now,
      httponly: true, same_site: :lax, secure: Rails.env.production?
    }
  end

  def terminate_session
    Current.session&.destroy
    cookies.delete(:session_id)
    reset_session
  end
end
