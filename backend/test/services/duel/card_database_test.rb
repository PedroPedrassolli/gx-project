require "test_helper"

class Duel::CardDatabaseTest < ActiveSupport::TestCase
  subject { Duel::Engine.cards }

  describe "#find" do
    it "traz os dados de um monstro Normal" do
      card = subject.find(46986414) # Dark Magician
      assert_equal [ 17, 2500, 2100, 7 ], [ card.type, card.attack, card.defense, card.level ]
    end

    it "separa os setcodes empacotados" do
      assert_equal [ 4258 ], subject.find(46986414).setcodes
    end

    it "separa nível e escalas de pêndulo" do
      card = subject.find(16178681) # Odd-Eyes Pendulum Dragon
      assert_equal [ 7, 4, 4, [ 153, 4338 ] ], [ card.level, card.lscale, card.rscale, card.setcodes ]
    end

    it "lê as setas do Link da DEF" do
      card = subject.find(1861629) # Decode Talker
      assert_equal [ 0, 133 ], [ card.defense, card.link_marker ]
    end
  end

  describe "#fill" do
    let(:data) { Duel::Native::CardData.new }

    it "preenche a estrutura da engine" do
      subject.fill(46986414, data)
      assert_equal [ 46986414, 2500, 32 ], [ data[:code], data[:attack], data[:attribute] ]
    end

    it "termina a lista de setcodes com zero" do
      subject.fill(46986414, data)
      assert_equal [ 4258, 0 ], data[:setcodes].read_array_of_uint16(2)
    end

    it "deixa só o código quando a carta não existe" do
      subject.fill(1, data)
      assert_equal [ 1, 0, 0 ], [ data[:code], data[:type], data[:setcodes].read_uint16 ]
    end
  end
end
