require "test_helper"

class Rooms::OpeningTest < ActiveSupport::TestCase
  include StarterDeckCards

  def player(name) = User.create!(email: "#{name.downcase}@example.com", password: "duelista123", nickname: name, age_group: "18+")

  let(:jaden) { player("Jaden") }
  let(:syrus) { player("Syrus") }
  let(:room) { Room.create!(owner: jaden, code: "ABC234") }
  let(:opening) { Rooms::Opening.new(room) }

  before do
    load_starter_deck_cards
    [ jaden, syrus ].each_with_index do |user, seat|
      Decks::StarterDeck.give_to(user)
      room.players.create!(user:, seat:, deck: user.decks.sole, ready: true)
    end
  end

  it "só vale com a sala cheia e todos prontos" do
    room.players.last.update!(ready: false)

    assert_nil opening.view(0)
    error = assert_raises(Rooms::Opening::Invalid) { opening.hand!(0, "rock") }
    assert_equal "Agora não é hora de escolher a mão.", error.message
  end

  it "a mão do outro fica escondida até os dois escolherem, e o empate começa outra rodada" do
    opening.hand!(0, "rock")
    assert_equal({ hand: nil, chosen: [ 0 ], last: nil, chooser_seat: nil }, opening.view(1))
    assert_equal "rock", opening.view(0)[:hand]

    opening.hand!(1, "rock")
    assert_equal({ hand: nil, chosen: [], last: { 0 => "rock", 1 => "rock" }, chooser_seat: nil }, opening.view(0))
  end

  it "recusa mão que não existe e a segunda mão na mesma rodada" do
    assert_equal "Escolha pedra, papel ou tesoura.", assert_raises(Rooms::Opening::Invalid) { opening.hand!(0, "lizard") }.message
    opening.hand!(0, "paper")
    assert_equal "Você já escolheu nesta rodada.", assert_raises(Rooms::Opening::Invalid) { opening.hand!(0, "rock") }.message
  end

  it "quem ganha escolhe; quem perdeu não; ir segundo põe o outro para começar" do
    opening.hand!(0, "scissors")
    opening.hand!(1, "paper")
    assert_equal 0, room.reload.chooser_seat
    assert_raises(Rooms::Opening::Invalid) { opening.hand!(1, "rock") }
    assert_raises(Rooms::Opening::Invalid) { opening.first!(1, true) }

    match = opening.first!(0, false)

    assert_equal [ syrus.id, jaden.id ], match.players.sort_by(&:team).map(&:user_id)
    assert_equal [ "dueling", {}, nil, nil ], [ room.reload.status, room.hands, room.last_hands, room.chooser_seat ]
  end

  it "cada mão vence uma: pedra quebra tesoura, papel embrulha pedra, tesoura corta papel" do
    { %w[rock scissors] => 0, %w[paper rock] => 0, %w[scissors paper] => 0, %w[rock paper] => 1 }.each do |(hand, other), winner|
      opening.reset!
      opening.hand!(0, hand)
      opening.hand!(1, other)
      assert_equal winner, room.reload.chooser_seat, "#{hand} contra #{other}"
    end
  end

  it "deck que deixou de valer: o duelo não começa e a escolha recomeça" do
    opening.hand!(0, "rock")
    opening.hand!(1, "scissors")
    syrus.decks.sole.deck_cards.where(section: "main").destroy_all

    assert_nil opening.first!(0, true)
    assert_equal [ "waiting", nil, [ true, false ] ], [ room.reload.status, room.chooser_seat, room.players.reload.map(&:ready) ]
  end
end
