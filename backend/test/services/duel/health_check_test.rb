require "test_helper"

class Duel::HealthCheckTest < ActiveSupport::TestCase
  subject { Duel::HealthCheck.run }

  describe ".run" do
    it "roda um duelo curto até a primeira pergunta" do
      assert_equal [ true, :select_chain ], subject.values_at(:ok, :first_prompt)
    end

    it "informa quanto tempo levou" do
      assert_operator subject[:ms], :>, 0
    end

    describe "quando a engine falha" do
      before { Duel::Engine.any_instance.stubs(:start).raises(Duel::Engine::Error, "sem biblioteca") }

      it "responde com o erro, sem derrubar o app" do
        assert_equal({ ok: false, error: "sem biblioteca" }, subject)
      end
    end
  end
end
