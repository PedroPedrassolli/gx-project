require "test_helper"

class Shop::ConverterTest < ActiveSupport::TestCase
  include CatalogFixture

  let(:user) { User.create!(email: "jaden@example.com", password: "duelista123", nickname: "JadenYuki", age_group: "18+") }
  let(:trap_hole) { Card.find_by!(name: "Trap Hole") }
  let(:assailant) { Card.find_by!(name: "Night Assailant") }
  let(:clear_wall) { Card.find_by!(name: "Clear Wall") }

  before do
    load_catalog
    CollectionCard.add!(user, { trap_hole.id => 8, assailant.id => 6, clear_wall.id => 1 })
  end

  def convert(cards, key: "conversao-1") = Shop::Converter.new(user, cards, key:).call

  def owned = user.collection_cards.pluck(:card_id, :quantity).to_h

  it "o que dá para converter: fica uma cópia de cada carta e o que o deck que mais usa precisa" do
    two_decks = [ user.decks.create!(name: "A"), user.decks.create!(name: "B") ]
    two_decks.first.deck_cards.create!(card: trap_hole, section: "main", quantity: 2)
    two_decks.first.deck_cards.create!(card: trap_hole, section: "side", quantity: 1)
    two_decks.second.deck_cards.create!(card: trap_hole, section: "main", quantity: 2)

    # Trap Hole: 8 - 3 (o deck A usa 3); Night Assailant: 6 - 1; Clear Wall: a única cópia fica.
    assert_equal({ trap_hole.id => 5, assailant.id => 5 }, Shop::Converter.spare(user))
  end

  it "gasta as repetidas, sorteia uma carta do grupo e põe na coleção; a mesma chave não gasta de novo" do
    conversion = convert({ trap_hole.id => 6, assailant.id => 5 })

    assert_equal [ 11, assailant.id ], [ conversion.amount, conversion.card_id ]
    assert_not conversion.new_card
    assert_equal({ trap_hole.id => 2, assailant.id => 2, clear_wall.id => 1 }, owned)
    assert_equal conversion, convert({ trap_hole.id => 6, assailant.id => 5 })
    assert_equal({ trap_hole.id => 2, assailant.id => 2, clear_wall.id => 1 }, owned)
  end

  it "a mesma semente sorteia a mesma carta, e a carta que o jogador não tinha vem como nova" do
    conversion = convert({ trap_hole.id => 5, assailant.id => 5 })
    group = ConverterGroup.find_by!(amount: 10).cards.order(:id).ids

    assert_equal group.sample(random: Random.new(conversion.seed)), conversion.card_id
    assert_equal conversion.card_id != trap_hole.id, conversion.new_card
    assert_equal({ trap_hole.id.to_s => 5, assailant.id.to_s => 5 }, conversion.spent)
  end

  it "recusa fora de 10 a 99 e cópia que não é repetida" do
    error = assert_raises(Shop::Converter::Invalid) { convert({ trap_hole.id => 7 }) }
    assert_equal "Escolha de 10 a 99 cartas.", error.message
    error = assert_raises(Shop::Converter::Invalid) { convert({ trap_hole.id => 8, assailant.id => 2 }) }
    assert_equal "Só dá para converter as cópias repetidas que nenhum deck usa.", error.message
    assert_raises(Shop::Converter::Invalid) { convert({ trap_hole.id => 11, assailant.id => -1 }) }
    assert_raises(Shop::Converter::Invalid) { convert({ trap_hole.id => 5, clear_wall.id => 5 }) }
    assert_equal({ trap_hole.id => 8, assailant.id => 6, clear_wall.id => 1 }, owned)
  end
end
