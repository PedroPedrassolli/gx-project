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

  describe ".win" do
    it "lê quem venceu e o motivo" do
      assert_equal({ player: 1, reason: 2 }, subject.win(subject.split(buffer).first))
    end
  end
end
