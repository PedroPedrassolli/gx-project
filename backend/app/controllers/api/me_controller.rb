# A conta do jogador logado e os direitos da LGPD sobre ela: baixar os dados e excluir a
# conta (escopo 3.1).
class Api::MeController < Api::BaseController
  before_action :require_authentication

  # GET /api/me/export: tudo o que guardamos do jogador, num JSON para baixar.
  def export
    send_data JSON.pretty_generate(Accounts::DataExport.new(current_user).as_json),
              filename: "gx-project-meus-dados.json", type: "application/json"
  end

  # DELETE /api/me: pede a senha de novo e apaga a conta, com sessões, coleção e decks.
  def destroy
    unless current_user.authenticate(params[:password].to_s)
      return render_error(:unprocessable_content, "Confira a senha.", { password: [ I18n.t("errors.messages.confirmation") ] })
    end

    current_user.destroy!
    cookies.delete(:session_id)
    head :no_content
  end
end
