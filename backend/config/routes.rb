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

    # Contas (ADR 0008): quem está logado, entrar e sair; cadastro.
    resource :session, only: %i[show create destroy]
    resources :registrations, only: :create
    resource :email_verification, only: %i[create update]
    resource :password, only: %i[create update]
    resource :me, only: :destroy, controller: "me" do
      get :export
    end
    resource :collection, only: :show
    resource :shop, only: :show, controller: "shop" do
      post :purchases, action: :purchase
    end
    post "realtime/token" => "realtime_tokens#create", as: :realtime_token
    resources :matches, only: :show do
      post :responses, on: :member, action: :respond
      post :surrender, on: :member
      post :emotes, on: :member, action: :emote
      post :settings, on: :member
      get :replay, on: :member
    end
    resources :rooms, only: %i[index show create], param: :code do
      member do
        post :join
        post :leave
        post :ready
        post :hand
        post :first
        post :kick
      end
    end
    resources :decks, only: %i[index show create update destroy] do
      collection do
        post :validate
        post :import
      end
      get :export, on: :member
    end
  end
end
