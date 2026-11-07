require "test_helper"

class Duel::EngineTest < ActiveSupport::TestCase
  # 20 cartas clássicas (monstros Normais e alguns de efeito), duas vezes.
  DECK = ([ 70781052, 91152256, 69140098, 14898066, 97590747, 11091375, 15025844, 13039848,
            43096270, 69247929, 12493482, 5053103, 49881766, 89631139, 46986414, 26202165,
            54652250, 71413901, 83011277, 74131780 ] * 2).freeze

  let(:seed) { [ 1, 2, 3, 4 ] }
  # O time 1 tem um monstro de Fusão no Extra Deck (Flame Swordsman).
  let(:decks) { [ { main: DECK }, { main: DECK.reverse, extra: [ 45231177 ] } ] }
  let(:no_chain) { [ -1 ].pack("l<") }

  subject { Duel::Engine.new(seed:, decks:) }

  after { subject.close }

  # Liga o duelo, manda as respostas e devolve todas as mensagens como [tipo, bytes].
  def play(engine, responses)
    messages = engine.start.advance
    responses.each do |response|
      engine.respond(response)
      messages += engine.advance
    end
    messages.map { |message| [ message.type, message.payload ] }
  end

  describe "#start e #advance" do
    it "chega à primeira pergunta sem erro de script" do
      prompt = Duel::MessageParser.prompt_name(subject.start.advance.last)
      assert_equal [ :select_chain, [] ], [ prompt, subject.errors ]
    end

    it "não termina o duelo na primeira pergunta" do
      subject.start.advance
      assert_not subject.finished?
    end
  end

  describe "determinismo (teste de contrato)" do
    let(:other) { Duel::Engine.new(seed:, decks:) }

    after { other.close }

    it "mesma semente, mesmos decks e mesmas respostas dão as mesmas mensagens" do
      assert_equal play(other, [ no_chain ]), play(subject, [ no_chain ])
    end
  end

  describe ".new" do
    it "aceita 2 decks (1x1) ou 4 (Tag), na ordem dos turnos" do
      assert_raises(ArgumentError) { Duel::Engine.new(seed:, decks: decks + [ { main: DECK } ]) }
    end
  end

  describe "quando algo falha ao começar" do
    it "avisa se a engine recusa o duelo" do
      Duel::Native.stubs(:create_duel).returns(3)
      assert_raises(Duel::Engine::Error) { subject.start }
    end

    it "avisa se falta um script base" do
      Duel::Engine.scripts.stubs(:read).returns(nil)
      assert_raises(Duel::Engine::Error) { subject.start }
    end

    it "avisa se a engine não carrega um script base" do
      Duel::Native.stubs(:load_script).returns(0)
      assert_raises(Duel::Engine::Error) { subject.start }
    end
  end

  describe "#close" do
    it "pode ser chamado mais de uma vez" do
      subject.start
      subject.close
      assert_nil subject.close
    end
  end

  describe "callbacks da engine" do
    it "o leitor de cartas não deixa exceção escapar para o C++" do
      Duel::Engine.cards.stubs(:fill).raises(RuntimeError, "falhou")
      assert_nil Duel::Engine::CARD_READER.call(nil, 123, Duel::Native::CardData.new.pointer)
    end

    it "o leitor de scripts responde 0 quando a leitura falha" do
      Duel::Engine.scripts.stubs(:read).raises(IOError, "disco")
      assert_equal 0, Duel::Engine::SCRIPT_READER.call(nil, nil, "c1.lua")
    end

    it "o leitor de scripts responde 0 para carta sem script" do
      assert_equal 0, Duel::Engine::SCRIPT_READER.call(nil, nil, "c46986414.lua")
    end

    it "erros de script ficam guardados no duelo que estava rodando" do
      Thread.current[:duel_engine] = subject
      Duel::Engine::LOG_HANDLER.call(nil, "linha 3: erro", Duel::Engine::LOG_ERROR)
      Duel::Engine::LOG_HANDLER.call(nil, "só um aviso", 2)
      assert_equal [ "linha 3: erro" ], subject.errors
    ensure
      Thread.current[:duel_engine] = nil
    end

    it "guarda no máximo #{Duel::Engine::MAX_ERRORS} erros" do
      25.times { subject.record_error("erro") }
      assert_equal Duel::Engine::MAX_ERRORS, subject.errors.size
    end
  end
end
