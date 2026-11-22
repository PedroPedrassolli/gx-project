require "test_helper"

class Characters::VictoryTest < ActiveSupport::TestCase
  include CharacterCards

  let(:user) { User.create!(email: "jaden@example.com", password: "duelista123", nickname: "Jaden", age_group: "18+") }

  # Uma partida já acabada contra o personagem: o jogador no time 0, o computador no 1.
  def finished(character, winner: 0)
    match = Match.create!(mode: "1x1", banlist: false, destiny_draw: true, seed: [ 1, 2, 3, 4 ], started_at: 5.minutes.ago,
                          status: "finished", winner_team: winner, finish_reason: "duel", finished_at: Time.current)
    match.players.create!(team: 0, seat: 0, user:, deck: {}, rewards: { "total" => 900 })
    match.players.create!(team: 1, seat: 1, character:, deck: {})
    match
  end

  def rewards(match) = match.players.find_by!(team: 0).reload.rewards

  it "na primeira vitória, dá a carta-símbolo e libera o próximo; nas outras, só conta" do
    load_character_cards("chumley")
    oz = Card.find_by!(name: "Master of Oz")
    first = finished("chumley")
    Characters::Victory.new(first).call
    again = finished("chumley")
    Characters::Victory.new(again).call

    assert_equal({ "total" => 900, "card" => { "id" => oz.id, "name" => "Master of Oz", "image" => oz.image_code },
                   "unlocked" => { "id" => "syrus", "name" => "Syrus" } }, rewards(first))
    assert_equal({ "total" => 900 }, rewards(again))
    assert_equal 1, user.collection_cards.find_by!(card: oz).quantity
    assert_equal 2, user.character_wins.find_by!(character: "chumley").wins
  end

  it "o último personagem não libera ninguém" do
    load_character_cards("yugi")
    match = finished("yugi")
    Characters::Victory.new(match).call

    assert_equal "Dark Magician", rewards(match).dig("card", "name")
    assert_not rewards(match).key?("unlocked")
  end

  it "na derrota e entre jogadores, nada muda" do
    Characters::Victory.new(finished("chumley", winner: 1)).call
    pvp = finished("chumley")
    pvp.bot.update!(character: nil)
    Characters::Victory.new(pvp.reload).call

    assert_empty CharacterWin.all
  end

  it "libera o próximo depois de vencer o anterior" do
    syrus = Characters::Roster.find("syrus")
    user.character_wins.create!(character: "chumley", wins: 1)
    progress = Characters::Progress.new(user)

    assert progress.unlocked?(Characters::Roster.find("chumley"))
    assert progress.unlocked?(syrus)
    assert_not progress.unlocked?(Characters::Roster.find("blair"))
    assert_equal [ 1, 0 ], [ progress.wins(Characters::Roster.find("chumley")), progress.wins(syrus) ]
  end
end
