require "test_helper"

class Matches::StartTest < ActiveSupport::TestCase
  include StarterDeckCards

  def player(name) = User.create!(email: "#{name.downcase}@example.com", password: "duelista123", nickname: name, age_group: "18+")

  let(:jaden) { player("Jaden") }
  let(:syrus) { player("Syrus") }
  let(:room) { Room.create!(owner: jaden, code: "ABC234", destiny_draw: false) }

  before do
    load_starter_deck_cards
    [ jaden, syrus ].each_with_index do |user, seat|
      Decks::StarterDeck.give_to(user)
      room.players.create!(user:, seat:, deck: user.decks.sole, ready: true)
    end
  end

  it "com todos prontos, cria a partida com os decks embaralhados e põe a sala em duelo" do
    match = Matches::Start.new(room).call

    assert_equal [ "dueling", "dueling", false, 4 ], [ room.reload.status, match.status, match.destiny_draw, match.seed.size ]
    assert_equal [ [ 0, 1 ], [ jaden.id, syrus.id ] ], [ match.players.map(&:team), match.players.map(&:user_id).sort ]
    rows = jaden.decks.sole.deck_cards.includes(:card).select { |row| row.section == "main" }
    deck = match.players.find_by!(user: jaden).deck
    assert_equal rows.flat_map { |row| [ row.card.engine_code ] * row.quantity }.sort, deck["main"].sort
    assert_equal [ [], rows.select(&:destiny).map { |row| row.card.engine_code } ], deck.values_at("extra", "destiny")
  end

  it "deck mexido depois do pronto não entra no duelo: o dono dele deixa de estar pronto" do
    # Depois do pronto, o Main ficou vazio (salvar deck incompleto vale; duelar com ele, não).
    syrus.decks.sole.deck_cards.where(section: "main").destroy_all

    assert_nil Matches::Start.new(room).call
    assert_equal [ "waiting", 0, [ true, false ] ], [ room.reload.status, Match.count, room.players.reload.map(&:ready) ]
  end

  it "sem todos prontos, não começa" do
    room.players.last.update!(ready: false)

    assert_nil Matches::Start.new(room).call
    assert_equal [ "waiting", 0 ], [ room.reload.status, Match.count ]
  end
end
