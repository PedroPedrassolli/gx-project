# As missões do jogador (escopo 3.5; GXP-89), com o progresso de cada uma. As regras ficam em
# db/seeds/missoes.yml e Economy::Missions.
class Api::MissionsController < Api::BaseController
  before_action :require_authentication

  def index
    render json: { data: Economy::Missions.new(current_user).progress }
  end
end
