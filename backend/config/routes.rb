Rails.application.routes.draw do
  # Saúde do app: o Rails responde 200 se subiu sem erro.
  get "up" => "rails/health#show", as: :rails_health_check
  # Saúde do banco. O uptime.yml chama a cada 4 h, o que também evita a pausa do
  # Supabase por falta de uso.
  get "up/db" => "health/databases#show", as: :database_health_check
end
