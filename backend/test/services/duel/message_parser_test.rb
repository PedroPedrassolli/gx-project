require "test_helper"

class Duel::MessageParserTest < ActiveSupport::TestCase
  # Duas mensagens como a engine manda: [tamanho][tipo][conteúdo].
  let(:buffer) { [ 3, 5, 1, 2 ].pack("L<CCC") + [ 1, 11 ].pack("L<C") }

  subject { Duel::MessageParser }

  describe ".split" do
    it "separa as mensagens pelo tamanho de cada uma" do
      assert_equal [ [ 5, "\x01\x02".b ], [ 11, "".b ] ], subject.split(buffer).map { |message| [ message.type, message.payload ] }
    end

    it "devolve lista vazia para buffer vazio" do
      assert_empty subject.split("".b)
    end
  end

  describe ".prompt_name" do
    it "dá nome às perguntas" do
      assert_equal :select_idlecmd, subject.prompt_name(subject.split(buffer).last)
    end

    it "ignora o que não é pergunta" do
      assert_nil subject.prompt_name(subject.split(buffer).first)
    end
  end

  describe ".select_hint" do
    def hint(player, data, type: 3) = Duel::MessageParser::Message.new(type: Duel::MessageParser::HINT, payload: [ type, player, data ].pack("CCQ<"))

    let(:select_card) { { type: :select_card, player: 0 } }

    it "pega o que a pergunta pede para escolher, da última dica para quem responde" do
      assert_equal 502, subject.select_hint([ hint(0, 549), hint(1, 506), hint(0, 502) ], select_card)
    end

    it "ignora a dica zerada, a de outro tipo e a pergunta que tem texto próprio" do
      assert_nil subject.select_hint([ hint(0, 502), hint(0, 0) ], select_card)
      assert_nil subject.select_hint([ hint(0, 502, type: 2) ], select_card)
      assert_nil subject.select_hint([ hint(0, 502) ], { type: :select_idlecmd, player: 0 })
    end
  end

  describe ".win" do
    it "lê quem venceu e o motivo" do
      assert_equal({ player: 1, reason: 2 }, subject.win(subject.split(buffer).first))
    end
  end
end
