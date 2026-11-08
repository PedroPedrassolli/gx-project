require "test_helper"

class RackAttackTest < ActionDispatch::IntegrationTest
  # Nos testes o cache é nulo; aqui os contadores precisam de um de verdade.
  before do
    @store = Rack::Attack.cache.store
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
  end
  after { Rack::Attack.cache.store = @store }

  def log_in(email) = post(api_session_path, params: { email:, password: "errada123" }, as: :json)

  # Hora fixa: o contador do Rack::Attack começa de novo a cada minuto (ou hora) cheio.
  def at_noon(&) = travel_to(Time.zone.local(2026, 11, 8, 12), &)

  it "barra o 6º login no mesmo e-mail dentro de 1 minuto, com mensagem em português" do
    at_noon do
      5.times { log_in("jaden@example.com") }
      _(response.status).must_equal 401

      log_in(" JADEN@example.com")
      _(response.status).must_equal 429
      _(response.parsed_body["error"]["message"]).must_equal "Muitas tentativas. Espere um pouco e tente de novo."

      log_in("outra.conta@example.com")
      _(response.status).must_equal 401
    end
  end

  it "barra o 31º login do mesmo IP dentro de 1 minuto, em contas diferentes" do
    at_noon do
      30.times { |n| log_in("jogador#{n}@example.com") }
      _(response.status).must_equal 401

      log_in("mais.um@example.com")
      _(response.status).must_equal 429
    end
  end

  it "conta pelo IP do jogador, que a Vercel manda no X-Real-IP" do
    at_noon do
      from = ->(ip, email) { post api_session_path, params: { email:, password: "errada123" }, headers: { "X-Real-IP" => ip }, as: :json }
      30.times { |n| from.call("200.1.1.1", "jogador#{n}@example.com") }
      from.call("200.1.1.1", "mais.um@example.com")
      _(response.status).must_equal 429

      from.call("200.2.2.2", "outro@example.com")
      _(response.status).must_equal 401
    end
  end

  it "barra o 11º cadastro do mesmo IP dentro de 1 hora" do
    at_noon do
      10.times { post api_registrations_path, params: { email: "x" }, as: :json }
      _(response.status).must_equal 422

      post api_registrations_path, params: { email: "y" }, as: :json
      _(response.status).must_equal 429
    end
  end

  it "barra o 6º pedido de troca de senha para o mesmo e-mail dentro de 1 hora" do
    at_noon do
      5.times { post api_password_path, params: { email: "jaden@example.com" }, as: :json }
      _(response.status).must_equal 202

      post api_password_path, params: { email: "Jaden@example.com" }, as: :json
      _(response.status).must_equal 429
    end
  end

  it "ignora corpo que não é JSON e deixa o Rails responder" do
    post api_session_path, params: "email=jaden", headers: { "Content-Type" => "text/plain" }

    _(response.status).must_equal 401
  end
end
