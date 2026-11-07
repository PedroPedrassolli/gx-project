require "test_helper"

class Duel::ByteReaderTest < ActiveSupport::TestCase
  let(:bytes) { [ 7, 513, 70_000, -2, 2**40 ].pack("CS<L<l<Q<") }

  subject { Duel::ByteReader.new(bytes) }

  describe "números" do
    it "lê cada tamanho em ordem, em little-endian" do
      assert_equal [ 7, 513, 70_000, -2, 2**40 ], [ subject.u8, subject.u16, subject.u32, subject.i32, subject.u64 ]
    end
  end

  describe "#location" do
    let(:bytes) { [ 1, 4, 2, 8 ].pack("CCL<L<") }

    it "lê o loc_info da engine" do
      assert_equal({ controller: 1, location: 4, sequence: 2, position: 8 }, subject.location)
    end
  end

  describe "#list" do
    let(:bytes) { [ 2, 10, 20 ].pack("L<CC") }

    it "usa a quantidade da frente para ler os itens" do
      assert_equal [ 10, 20 ], subject.list { subject.u8 }
    end
  end

  describe "mensagem curta demais" do
    let(:bytes) { "\x01".b }

    it "avisa em vez de devolver lixo" do
      assert_raises(Duel::ByteReader::TruncatedError) { subject.u32 }
    end
  end
end
