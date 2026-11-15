require "test_helper"

class Economy::DuelRewardsTest < ActiveSupport::TestCase
  include StarterDeckCards

  def player(name, **attributes)
    User.create!(email: "#{name.downcase}@example.com", password: "duelista123", nickname: name, age_group: "18+", **attributes)
  end

  let(:jaden) { player("Jaden", created_at: 30.days.ago) }
  let(:syrus) { player("Syrus", created_at: 30.days.ago) }

  before { load_starter_deck_cards }

  # Uma partida entre os dois, com o Jaden no time 0; turns e minutes dizem quanto ela durou.
  def match(turns: 6, minutes: 10)
    @room ||= Room.create!(owner: jaden, code: Room.new_code).tap do |room|
      [ jaden, syrus ].each_with_index do |user, seat|
        Decks::StarterDeck.give_to(user)
        room.players.create!(user:, seat:, deck: user.decks.sole)
      end
    end
    @room.players.update_all(ready: true)
    Matches::Start.new(@room, first_seat: 0).call.tap { |match| match.update!(turn: turns, started_at: minutes.minutes.ago) }
  end

  # O Syrus desiste: o Jaden vence (sem as formas de vencer, que são só da engine).
  def surrender(match) = Matches::Game.new(match).surrender!(1)

  def rewards(user, match) = match.players.find_by!(user:).rewards

  it "credita os bônus dos dois no razão e guarda o resumo para a tela de resultado" do
    played = match
    surrender(played)

    won = rewards(jaden, played)
    assert_equal({ "level" => 2, "turns" => 12, "network_win" => 50, "duelist" => 90 }, won["lines"].to_h { |line| line.values_at("key", "dp") })
    assert_equal [ 154, [], 154, 1 ], won.values_at("total", "cuts", "balance", "level")
    assert_equal [ 18, 18 ], rewards(syrus, played).values_at("total", "balance")
    assert_equal [ "duel", "partida:#{played.id}", played ], jaden.dp_transactions.sole.then { |line| [ line.reason, line.key, line.ref ] }
  end

  it "duelo curto e o segundo contra o mesmo oponente no dia pagam menos" do
    surrender(match(turns: 2))
    assert_equal [ 10, [ "short" ] ], rewards(jaden, Match.last).then { |data| [ data["total"], data["cuts"].pluck("key") ] }

    surrender(match)
    assert_equal [ 77, [ "same_opponent" ] ], rewards(jaden, Match.last).then { |data| [ data["total"], data["cuts"].pluck("key") ] }
  end

  it "o DP ganho sobe o nível, e cada nível novo paga 400" do
    jaden.update!(dp_earned: 990)
    played = match
    surrender(played)

    assert_equal [ { "key" => "level_up", "label" => "Subiu para o nível 2", "dp" => 400 } ], rewards(jaden, played)["level_ups"]
    assert_equal [ 554, 2, 554, 1_544 ], [ rewards(jaden, played)["total"], jaden.reload.level, Economy::Ledger.balance(jaden), jaden.dp_earned ]
  end

  it "quem apagou a conta fica de fora" do
    played = match
    syrus.destroy!
    surrender(played)

    assert_nil played.players.find_by(team: 1).rewards
    assert_equal 154, rewards(jaden, played)["total"]
  end
end
