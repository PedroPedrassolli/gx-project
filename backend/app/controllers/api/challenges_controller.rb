# Os desafios do jogador (escopo 3.5; GXP-88): os 104, na ordem do jogo, com os que ele já
# concluiu. As condições ficam em Economy::Challenges.
class Api::ChallengesController < Api::BaseController
  before_action :require_authentication

  # GET /api/challenges: possible é falso nos que ainda não dá para concluir.
  def index
    done = current_user.user_challenges.pluck(:number).to_set
    challenges = Economy::Challenges::LIST.map do |challenge|
      challenge.slice(:number, :label).merge(done: done.include?(challenge[:number]), possible: challenge[:check].present?)
    end
    render json: { data: { done: done.size, total: challenges.size, challenges: } }
  end
end
