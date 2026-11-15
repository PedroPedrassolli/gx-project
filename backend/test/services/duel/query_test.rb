require "test_helper"

class Duel::QueryTest < ActiveSupport::TestCase
  describe "na engine de verdade" do
    let(:recording) { Duel::HealthCheck.recording }
    let(:engine) { Duel::Engine.new(seed: recording[:seed], decks: recording[:decks]).start.tap(&:advance) }

    after { engine.close }

    it "no começo, cada lado tem 8000 de PV, a mão inicial e o resto no deck" do
      field = engine.query_field

      assert_equal [ 8000, 8000 ], field.pluck(:lp)
      field.each_with_index do |side, team|
        assert_equal recording[:decks][team][:main].size, side[:deck] + side[:hand]
        assert_operator side[:hand], :>=, 5
        assert_equal [ 0, 0 ], side.values_at(:grave, :banished)
      end
    end

    it "a mão traz o código das cartas, e as zonas vazias vêm como nil" do
      hand = engine.query_location(1, Duel::Query::HAND)

      assert_equal engine.query_field[1][:hand], hand.size
      assert(hand.all? { |card| recording[:decks][1][:main].include?(card[:code]) })
      assert_equal [ nil ] * 7, engine.query_location(1, Duel::Query::MONSTERS)
    end
  end

  describe ".cards" do
    def field(flag, value) = [ 4 + value.bytesize, flag ].pack("S<L<") + value
    def last = [ 4, Duel::Query::LAST ].pack("S<L<")

    it "lê código, posição, ATK/DEF negativos e se está à vista, pulando o que não conhece" do
      card = field(Duel::Query::CODE, [ 46_986_414 ].pack("L<")) + field(0x40, [ 32 ].pack("L<")) +
             field(Duel::Query::ATTACK, [ -2 ].pack("l<")) + field(Duel::Query::IS_PUBLIC, "\x01") + last
      empty = [ 0 ].pack("S<")
      body = empty + card

      assert_equal [ nil, { code: 46_986_414, atk: -2, public: true } ], Duel::Query.cards([ body.bytesize ].pack("L<") + body)
    end

    it "buffer cortado no meio dá erro" do
      body = field(Duel::Query::CODE, [ 1 ].pack("L<"))

      assert_raises(Duel::ByteReader::TruncatedError) { Duel::Query.cards([ body.bytesize + 4 ].pack("L<") + body) }
    end
  end
end
