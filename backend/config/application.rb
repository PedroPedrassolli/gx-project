require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"
require "action_mailer/railtie"
# O Solid Cache traz um job de limpeza (não usado: a limpeza roda numa thread) que precisa
# do Active Job carregado.
require "active_job/railtie"
require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Backend
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # Horário de São Paulo (as datas continuam gravadas em UTC) e mensagens em português,
    # com o inglês do Rails para o que não tiver tradução.
    config.time_zone = "Brasilia"
    # Endereço do site, para os links dos e-mails.
    config.x.app_url = ENV.fetch("APP_URL", "https://gx-project-two.vercel.app")
    config.i18n.default_locale = :"pt-BR"
    config.i18n.fallbacks = [ :en ]

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true

    # Cookies e sessão do Rails, que o modo API tira. A sessão só guarda o token CSRF; o
    # login fica no cookie session_id (ADR 0008). Rota que não mexe na sessão não cria cookie.
    config.session_store :cookie_store, key: "_gx_session", same_site: :lax, secure: Rails.env.production?
    config.middleware.use ActionDispatch::Cookies
    config.middleware.use config.session_store, config.session_options
  end
end
