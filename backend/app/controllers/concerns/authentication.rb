# Login por cookie (ADR 0008), como o gerador de autenticação do Rails 8, só que em JSON.
module Authentication
  extend ActiveSupport::Concern

  private

  def current_user
    Current.session ||= find_session_by_cookie
    Current.user
  end

  def find_session_by_cookie
    Session.find_by(id: cookies.signed[:session_id]) if cookies.signed[:session_id]
  end

  def start_new_session_for(user)
    Current.session = user.sessions.create!
    cookies.signed.permanent[:session_id] = {
      value: Current.session.id, httponly: true, same_site: :lax, secure: Rails.env.production?
    }
  end

  def terminate_session
    Current.session&.destroy
    cookies.delete(:session_id)
  end
end
