require "test_helper"

class Duel::HealthCheckTest < ActiveSupport::TestCase
  subject { Duel::HealthCheck.run }

  let(:recording) { Duel::HealthCheck.recording }

  describe ".run" do
    it "refaz o duelo gravado inteiro e chega ao mesmo vencedor" do
      assert_equal [ true, 403, 1 ], subject.values_at(:ok, :responses, :winner)
    end

    it "a ação fria (duelo refeito do zero) custa mais que a quente (engine no cache)" do
      assert_operator subject[:cold_ms], :>, subject[:warm_ms]
    end

    describe "quando a gravação não bate mais com a engine" do
      # Faltando respostas, o duelo para no meio e ninguém vence.
      before do
        responses = recording[:responses].first(10)
        Duel::HealthCheck.stubs(:recording).returns(recording.merge(responses:))
      end

      it "acusa a falha" do
        assert_equal [ false, nil ], subject.values_at(:ok, :winner)
      end
    end

    describe "quando a engine recusa uma resposta da gravação" do
      before do
        responses = recording[:responses][0...-1] + [ "ffffff7f" ]
        Duel::HealthCheck.stubs(:recording).returns(recording.merge(responses:))
      end

      it "responde com o erro" do
        assert_equal({ ok: false, error: "a engine recusou a resposta" }, subject)
      end
    end

    describe "quando a engine falha" do
      before { Duel::Engine.any_instance.stubs(:start).raises(Duel::Engine::Error, "sem biblioteca") }

      it "responde com o erro, sem derrubar o app" do
        assert_equal({ ok: false, error: "sem biblioteca" }, subject)
      end
    end
  end

  describe ".runtime" do
    it "diz se o Ruby roda com o YJIT" do
      _([ true, false ]).must_include Duel::HealthCheck.runtime[:yjit]
    end

    it "acha o jemalloc entre as bibliotecas carregadas no processo" do
      File.stubs(:exist?).with("/proc/self/maps").returns(true)
      File.stubs(:read).with("/proc/self/maps").returns("7f3c r-xp 00000000 /usr/lib/x86_64-linux-gnu/libjemalloc.so.2\n")

      _(Duel::HealthCheck.runtime[:jemalloc]).must_equal true
    end

    it "sem o jemalloc, ou fora do Linux, responde false" do
      File.stubs(:exist?).with("/proc/self/maps").returns(false)

      _(Duel::HealthCheck.runtime[:jemalloc]).must_equal false
    end
  end
end
