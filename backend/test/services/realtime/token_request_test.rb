require "test_helper"

class Realtime::TokenRequestTest < ActiveSupport::TestCase
  subject { Realtime::TokenRequest.new("app.chave:segredo").for_user(42, timestamp: 1_700_000_000_000, nonce: "0123456789abcdef") }

  describe "#for_user" do
    it "só deixa assinar o canal do próprio jogador" do
      assert_equal({ "private:user:42" => [ "subscribe" ] }, JSON.parse(subject[:capability]))
    end

    it "prende o token ao jogador e dura 1 hora" do
      assert_equal [ "app.chave", "42", 3_600_000 ], subject.values_at(:keyName, :clientId, :ttl)
    end

    # Spec do Ably: HMAC-SHA256 com o segredo da chave, em base64, dos campos keyName, ttl,
    # capability, clientId, timestamp e nonce, cada um seguido de "\n".
    it "assina os campos na ordem do Ably" do
      text = "app.chave\n3600000\n{\"private:user:42\":[\"subscribe\"]}\n42\n1700000000000\n0123456789abcdef\n"
      assert_equal Base64.strict_encode64(OpenSSL::HMAC.digest("SHA256", "segredo", text)), subject[:mac]
    end

    it "gera um nonce novo e usa a hora atual quando não recebe" do
      first, second = Array.new(2) { Realtime::TokenRequest.new("app.chave:segredo").for_user(42) }
      assert_equal [ true, true ], [ first[:nonce] != second[:nonce], (first[:timestamp] - (Time.now.to_f * 1000)).abs < 5000 ]
    end
  end
end
