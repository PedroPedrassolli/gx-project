require "test_helper"

class Duel::SessionTest < ActiveSupport::TestCase
  let(:recording) { Duel::HealthCheck.recording }
  let(:responses) { recording[:responses].map { |hex| [ hex ].pack("H*") } }
  let(:cache) { Duel::EngineCache.new(4) }

  # Como o servidor monta a sessão a cada ação: dados do banco + o cache da instância.
  def session(given, id: "duelo-1", cache: self.cache)
    Duel::Session.new(id:, seed: recording[:seed], decks: recording[:decks], responses: given, cache:)
  end

  # Mensagens de referência: o duelo refeito do zero, sem cache nenhum.
  def reference(step)
    session(responses.first(step), id: "referência", cache: Duel::EngineCache.new(1)).respond(responses[step])
  end

  describe ".new" do
    it "repassa as regras do duelo (PV inicial, Destiny Draw) para a engine" do
      rules = { starting_lp: 3000, destiny_draw: true }
      engine = Duel::Engine.new(seed: recording[:seed], decks: recording[:decks], **rules)
      Duel::Engine.expects(:new).with(seed: recording[:seed], decks: recording[:decks], **rules).returns(engine)
      Duel::Session.new(id: "duelo-1", seed: recording[:seed], decks: recording[:decks], cache:, **rules).start
    end
  end

  describe "#start" do
    it "devolve as mensagens até a primeira pergunta e guarda a engine" do
      messages = session([]).start
      assert_equal [ true, 1 ], [ Duel::MessageParser::PROMPTS.key?(messages.last.type), cache.size ]
    end

    it "não começa de novo um duelo que já tem respostas" do
      assert_raises(ArgumentError) { session(responses.first(1)).start }
    end
  end

  describe "#respond" do
    it "com o duelo no cache, só processa a resposta nova" do
      expected = reference(0)
      session([]).start
      Duel::Engine.expects(:new).never
      assert_equal expected, session([]).respond(responses[0])
    end

    it "sem o duelo no cache, refaz pelo replay e chega às mesmas mensagens" do
      assert_equal reference(10), session(responses.first(10)).respond(responses[10])
    end

    it "refaz o duelo quando o cache está em outro ponto (outra instância avançou)" do
      session([]).start
      assert_equal reference(5), session(responses.first(5)).respond(responses[5])
    end

    it "guarda a resposta no histórico da sessão" do
      current = session(responses.first(3))
      current.respond(responses[3])
      assert_equal responses.first(4), current.responses
    end

    describe "quando a engine recusa a resposta" do
      let(:invalid) { [ 0x7fffffff ].pack("l<") }

      it "avisa e não guarda a resposta" do
        current = session(responses.first(3))
        assert_raises(Duel::Session::InvalidResponse) { current.respond(invalid) }
        assert_equal responses.first(3), current.responses
      end

      it "continua na mesma pergunta, com a engine no cache" do
        expected = reference(0)
        assert_raises(Duel::Session::InvalidResponse) { session([]).tap(&:start).respond(invalid) }
        Duel::Engine.expects(:new).never
        assert_equal expected, session([]).respond(responses[0])
      end
    end

    describe "na resposta que termina o duelo" do
      subject { session(responses[0...-1]) }

      it "devolve o MSG_WIN e marca o fim" do
        messages = subject.respond(responses.last)
        assert_equal [ Duel::MessageParser::WIN, true ], [ messages.last.type, subject.finished? ]
      end

      it "não guarda a engine no cache" do
        subject.respond(responses.last)
        assert_equal 0, cache.size
      end
    end
  end
end
