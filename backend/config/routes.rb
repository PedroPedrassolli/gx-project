Rails.application.routes.draw do
  # Saúde do app: o Rails responde 200 se subiu sem erro.
  get "up" => "rails/health#show", as: :rails_health_check
  # Saúde do banco. O uptime.yml chama a cada 4 h, o que também evita a pausa do
  # Supabase por falta de uso.
  get "up/db" => "health/databases#show", as: :database_health_check
  # Saúde da engine de duelo: refaz um duelo gravado e responde com o tempo gasto.
  get "up/engine" => "health/engines#show", as: :engine_health_check

  # API do front (escopo 5.6), no mesmo domínio: o vercel.json repassa /api/* para o Rails.
  namespace :api do
    resources :cards, only: %i[index show]
    resources :packs, only: :index
    resources :banlists, only: :index
  end
end
