require "test_helper"
require "net/http"

class Realtime::AblyPublisherTest < ActiveSupport::TestCase
  subject { Realtime::AblyPublisher.new("app.chave:segredo") }

  let(:http) { connection_mock("http") }

  # Conexão falsa, já configurada e aberta como o publicador faz.
  def connection_mock(name)
    mock(name).tap do |connection|
      connection.stubs(:use_ssl=)
      connection.stubs(:open_timeout=)
      connection.stubs(:read_timeout=)
      connection.stubs(:keep_alive_timeout=)
      connection.stubs(:start)
    end
  end

  # Captura a requisição que iria para o Ably e responde com o status pedido.
  def answer_with(response)
    sent = []
    http.expects(:request).with { |request| sent << request }.returns(response)
    Net::HTTP.expects(:new).with("main.realtime.ably.net", 443).returns(http)
    sent
  end

  # Cada teste começa sem conexão guardada na thread.
  before { Thread.current[Realtime::AblyPublisher::CONNECTION] = nil }
  after { Thread.current[Realtime::AblyPublisher::CONNECTION] = nil }

  describe "#publish" do
    it "manda um POST no canal do jogador, com a chave em Basic auth" do
      sent = answer_with(Net::HTTPCreated.new("1.1", "201", "Created"))
      subject.publish(user_id: 7, event: "duel.delta", data: { seq: 3 })
      request = sent.first
      assert_equal [ "/channels/private%3Auser%3A7/messages", "Basic #{Base64.strict_encode64("app.chave:segredo")}" ],
                   [ request.path, request["Authorization"] ]
    end

    it "se identifica como o servidor (canal privado pode exigir cliente identificado)" do
      sent = answer_with(Net::HTTPCreated.new("1.1", "201", "Created"))
      subject.publish(user_id: 7, event: "duel.delta", data: { seq: 3 })
      assert_equal "gx-project-server", Base64.strict_decode64(sent.first["X-Ably-ClientId"])
    end

    it "manda o nome e os dados do evento em JSON" do
      sent = answer_with(Net::HTTPCreated.new("1.1", "201", "Created"))
      subject.publish(user_id: 7, event: "duel.delta", data: { seq: 3 })
      assert_equal({ "name" => "duel.delta", "data" => { "seq" => 3 } }, JSON.parse(sent.first.body))
    end

    it "avisa quando o Ably recusa, com o motivo que ele dá" do
      refused = Net::HTTPUnauthorized.new("1.1", "401", "Unauthorized")
      refused.stubs(:body).returns('{"error":{"code":40160,"message":"Action not permitted"}}')
      answer_with(refused)
      error = assert_raises(Realtime::AblyPublisher::Error) { subject.publish(user_id: 7, event: "duel.delta", data: {}) }
      assert_equal "o Ably respondeu 401 (40160: Action not permitted)", error.message
    end

    it "reaproveita a conexão aberta nos avisos seguintes" do
      created = Net::HTTPCreated.new("1.1", "201", "Created")
      Net::HTTP.expects(:new).once.returns(http)
      http.expects(:request).twice.returns(created)
      2.times { subject.publish(user_id: 7, event: "duel.updated", data: {}) }
    end

    it "se a conexão caiu parada, abre outra e tenta mais uma vez" do
      fresh = connection_mock("nova")
      Net::HTTP.expects(:new).twice.returns(http, fresh)
      http.expects(:request).raises(EOFError)
      fresh.expects(:request).returns(Net::HTTPCreated.new("1.1", "201", "Created"))
      subject.publish(user_id: 7, event: "duel.updated", data: {})
    end

    it "transforma erro de rede (sem conexão, tempo esgotado) no erro do publicador" do
      Net::HTTP.expects(:new).returns(http)
      http.expects(:start).raises(Net::OpenTimeout)
      error = assert_raises(Realtime::AblyPublisher::Error) { subject.publish(user_id: 7, event: "duel.delta", data: {}) }
      assert_equal "sem conexão com o Ably (Net::OpenTimeout)", error.message
    end

    it "avisa só com o status quando a resposta não explica" do
      broken = Net::HTTPBadGateway.new("1.1", "502", "Bad Gateway")
      broken.stubs(:body).returns("<html>erro</html>")
      answer_with(broken)
      error = assert_raises(Realtime::AblyPublisher::Error) { subject.publish(user_id: 7, event: "duel.delta", data: {}) }
      assert_equal "o Ably respondeu 502", error.message
    end

    it "avisa só com o status quando o JSON não traz erro" do
      odd = Net::HTTPForbidden.new("1.1", "403", "Forbidden")
      odd.stubs(:body).returns("{}")
      answer_with(odd)
      error = assert_raises(Realtime::AblyPublisher::Error) { subject.publish(user_id: 7, event: "duel.delta", data: {}) }
      assert_equal "o Ably respondeu 403", error.message
    end
  end
end
