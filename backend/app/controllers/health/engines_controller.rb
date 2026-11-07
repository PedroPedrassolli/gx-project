# Confere se a engine de duelo roda neste servidor (biblioteca nativa, scripts e cartas).
class Health::EnginesController < ApplicationController
  # GET /up/engine
  def show
    result = Duel::HealthCheck.run
    render json: result, status: result[:ok] ? :ok : :service_unavailable
  end
end
