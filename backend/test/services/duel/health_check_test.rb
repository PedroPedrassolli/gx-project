require "test_helper"

class Duel::HealthCheckTest < ActiveSupport::TestCase
  subject { Duel::HealthCheck.run }

  describe ".run" do
    it "refaz o duelo gravado inteiro e chega ao mesmo vencedor" do
      assert_equal [ true, 403, 1 ], subject.values_at(:ok, :responses, :winner)
    end

    it "informa quanto tempo levou" do
      assert_operator subject[:ms], :>, 0
    end

    describe "quando a gravação não bate mais com a engine" do
      # Faltando respostas, o duelo para no meio e ninguém vence.
      before do
        recording = Duel::HealthCheck.recording
        Duel::HealthCheck.stubs(:recording).returns(recording.merge(responses: recording[:responses].first(10)))
      end

      it "acusa a falha" do
        assert_equal [ false, nil ], subject.values_at(:ok, :winner)
      end
    end

    describe "quando a engine falha" do
      before { Duel::Engine.any_instance.stubs(:start).raises(Duel::Engine::Error, "sem biblioteca") }

      it "responde com o erro, sem derrubar o app" do
        assert_equal({ ok: false, error: "sem biblioteca" }, subject)
      end
    end
  end
end
