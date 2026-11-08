# Cadastro (escopo 3.1; ADR 0008): cria a conta e já entra.
class Api::RegistrationsController < Api::BaseController
  # POST /api/registrations
  def create
    registration = Accounts::Registration.new(params.permit(:email, :password, :nickname, :birth_date, :terms_accepted))
    unless registration.save
      return render_error(:unprocessable_content, "Confira os campos.", registration.user.errors.to_hash)
    end

    start_new_session_for(registration.user)
    render json: { user: registration.user }, status: :created
  end
end
