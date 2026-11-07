# Confere se o banco responde. Usado pelo monitor de disponibilidade (uptime.yml).
class Health::DatabasesController < ApplicationController
  # GET /up/db
  def show
    ActiveRecord::Base.connection.select_value("SELECT 1")
    render plain: "ok"
  rescue ActiveRecord::ActiveRecordError => error
    # A mensagem do erro pode ter o endereço do banco: vai só para o log.
    Rails.logger.warn("banco indisponível: #{error.class}")
    render plain: "banco indisponível", status: :service_unavailable
  end
end
