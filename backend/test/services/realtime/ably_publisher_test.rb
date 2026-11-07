require "test_helper"
require "net/http"

class Realtime::AblyPublisherTest < ActiveSupport::TestCase
  subject { Realtime::AblyPublisher.new("app.chave:segredo") }

  let(:http) { mock("http") }

  # Captura a requisição que iria para o Ably e responde com o status pedido.
  def answer_with(response)
    sent = []
    http.expects(:request).with { |request| sent << request }.returns(response)
    Net::HTTP.expects(:start).with("main.realtime.ably.net", 443, use_ssl: true, open_timeout: 2, read_timeout: 5)
             .yields(http).returns(response)
    sent
  end

  describe "#publish" do
    it "manda um POST no canal do jogador, com a chave em Basic auth" do
      sent = answer_with(Net::HTTPCreated.new("1.1", "201", "Created"))
      subject.publish(user_id: 7, event: "duel.delta", data: { seq: 3 })
      request = sent.first
      assert_equal [ "/channels/private%3Auser%3A7/messages", "Basic #{Base64.strict_encode64("app.chave:segredo")}" ],
                   [ request.path, request["Authorization"] ]
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
