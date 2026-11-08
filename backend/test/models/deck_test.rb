require "test_helper"

class DeckTest < ActiveSupport::TestCase
  include StarterDeckCards

  let(:user) { User.create!(email: "jaden@example.com", password: "duelista123", nickname: "JadenYuki", age_group: "13-17") }

  it "pede nome de até 40 caracteres" do
    _(user.decks.build(name: "").tap(&:validate).errors[:name]).must_include "não pode ficar em branco"
    _(user.decks.build(name: "D" * 41).tap(&:validate).errors[:name]).must_include "é longo demais (máximo de 40 caracteres)"
  end

  it "aceita só as seções main, extra e side, e de 1 a 3 cópias" do
    row = DeckCard.new(section: "baú", quantity: 4).tap(&:validate)

    _(row.errors[:section]).must_include "não está na lista"
    _(row.errors[:quantity]).wont_be_empty
  end

  it "não aceita carta com zero cópias na coleção" do
    _(CollectionCard.new(quantity: 0).tap(&:validate).errors[:quantity]).wont_be_empty
  end

  it "apaga decks e coleção junto com a conta" do
    load_starter_deck_cards
    Decks::StarterDeck.give_to(user)

    user.destroy

    _([ Deck.count, DeckCard.count, CollectionCard.count ]).must_equal [ 0, 0, 0 ]
  end
end
