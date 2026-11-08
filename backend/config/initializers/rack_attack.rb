# Limite de tentativas no login e no cadastro (escopo 6; ADR 0008). Os contadores ficam no
# Rails.cache, que em produção é o Solid Cache no Postgres: a memória de cada instância da
# Vercel não é dividida entre elas. Nos testes o cache é nulo, e nada é barrado.

login = ->(request) { request.post? && request.path == "/api/session" }

# IP de quem fez o pedido. Na Vercel, o X-Real-IP vem da própria Vercel, que sobrescreve o
# que o navegador mandar; fora dela (testes e desenvolvimento), vale o IP da conexão.
client_ip = ->(request) { request.get_header("HTTP_X_REAL_IP").presence || request.ip }
sign_up = ->(request) { request.post? && request.path == "/api/registrations" }

# E-mail do JSON do pedido, do jeito que fica guardado. O Rack::Attack roda antes de o
# Rails ler o corpo, então lê aqui e volta o corpo para o começo.
email = lambda do |request|
  data = JSON.parse(request.body.read)
  request.body.rewind
  data["email"].to_s.strip.downcase.presence if data.is_a?(Hash)
rescue JSON::ParserError
  nil
end

# Login: 5 por minuto por e-mail (quem tenta senhas de uma conta) e 30 por minuto por IP.
Rack::Attack.throttle("login por e-mail", limit: 5, period: 1.minute) do |request|
  email.call(request) if login.call(request)
end

Rack::Attack.throttle("login por IP", limit: 30, period: 1.minute) do |request|
  client_ip.call(request) if login.call(request)
end

# Cadastro: 10 por hora por IP (escola e casa dividem o mesmo IP).
Rack::Attack.throttle("cadastro por IP", limit: 10, period: 1.hour) do |request|
  client_ip.call(request) if sign_up.call(request)
end

# Troca de senha: 5 pedidos por hora por e-mail e 20 por hora por IP.
password_reset = ->(request) { request.post? && request.path == "/api/password" }

Rack::Attack.throttle("troca de senha por e-mail", limit: 5, period: 1.hour) do |request|
  email.call(request) if password_reset.call(request)
end

Rack::Attack.throttle("troca de senha por IP", limit: 20, period: 1.hour) do |request|
  client_ip.call(request) if password_reset.call(request)
end

# Reenvio do e-mail de confirmação: 5 por hora por IP (cada um gasta da cota do Brevo).
Rack::Attack.throttle("reenvio de confirmação por IP", limit: 5, period: 1.hour) do |request|
  client_ip.call(request) if request.post? && request.path == "/api/email_verification"
end

Rack::Attack.throttled_responder = lambda do |_request|
  body = { error: { status: 429, message: "Muitas tentativas. Espere um pouco e tente de novo." } }
  [ 429, { "content-type" => "application/json" }, [ body.to_json ] ]
end
