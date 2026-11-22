require "test_helper"

class Decks::StarterDeckTest < ActiveSupport::TestCase
  include StarterDeckCards

  let(:user) { User.create!(email: "jaden@example.com", password: "duelista123", nickname: "JadenYuki", age_group: "13-17") }

  before { load_starter_deck_cards }

  it "dá as cartas e o deck montado e válido, com 3 Destiny; as do Side vão só para a coleção" do
    travel_to Time.zone.local(2026, 11, 8, 12) do
      Decks::StarterDeck.give_to(user)
    end

    deck = user.decks.sole
    _(deck.name).must_equal "Deck inicial"
    _(deck.deck_cards.where(section: "main").sum(:quantity)).must_equal 40
    _(deck.deck_cards.where.not(section: "main").count).must_equal 0
    _(deck.deck_cards.where(destiny: true).count).must_equal 3
    _(user.collection_cards.sum(:quantity)).must_equal 55
    _(user.collection_cards.pluck(:obtained_at).uniq).must_equal [ Time.zone.local(2026, 11, 8, 12) ]
    # O deck inicial chega visto: no baú, "nova" é só a carta ganha depois.
    _(user.collection_cards.pluck(:seen_at).uniq).must_equal [ Time.zone.local(2026, 11, 8, 12) ]
    _(Decks::Validator.for(deck).errors).must_be_empty
  end

  it "avisa da carta do deck inicial que não está no banco" do
    Card.find_by!(name: "D.D. Assailant").destroy

    error = _ { Decks::StarterDeck.give_to(user) }.must_raise RuntimeError
    _(error.message).must_equal "Carta do deck inicial fora do banco: D.D. Assailant"
  end
end
