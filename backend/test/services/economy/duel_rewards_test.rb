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
    # Ninguém jogou nada: o vencedor leva também os bônus de vencer sem magia, sem armadilha e sem
    # Invocação-Especial (15, 15 e 10).
    assert_equal({ "level" => 2, "turns" => 12, "network_win" => 50, "duelist" => 90, "no_spells" => 15, "no_traps" => 15, "no_special" => 10 },
                 won["lines"].to_h { |line| line.values_at("key", "dp") })
    assert_equal [ 194, [], 194, 1 ], won.values_at("total", "cuts", "balance", "level")
    assert_equal [ 18, 18 ], rewards(syrus, played).values_at("total", "balance")
    assert_equal [ "duel", "partida:#{played.id}", played ], jaden.dp_transactions.sole.then { |line| [ line.reason, line.key, line.ref ] }
  end

  it "duelo curto e o segundo contra o mesmo oponente no dia pagam menos" do
    surrender(match(turns: 2))
    assert_equal [ 10, [ "short" ] ], rewards(jaden, Match.last).then { |data| [ data["total"], data["cuts"].pluck("key") ] }

    surrender(match)
    assert_equal [ 97, [ "same_opponent" ] ], rewards(jaden, Match.last).then { |data| [ data["total"], data["cuts"].pluck("key") ] }
  end

  it "o DP ganho sobe o nível, e cada nível novo paga 400" do
    jaden.update!(dp_earned: 990)
    played = match
    surrender(played)

    assert_equal [ { "key" => "level_up", "label" => "Subiu para o nível 2", "dp" => 400 } ], rewards(jaden, played)["level_ups"]
    assert_equal [ 594, 2, 594, 1_584 ], [ rewards(jaden, played)["total"], jaden.reload.level, Economy::Ledger.balance(jaden), jaden.dp_earned ]
  end

  it "as contas do duelo viram bônus, com o nome das cartas invocadas e usadas" do
    Card.insert_all!([ [ 1, "Gate Guardian" ], [ 2, "Illusion Gate" ], [ 3, "Skull Servant" ] ].map do |code, name|
      { engine_code: code, name:, card_type: "Monster", monster_types: [], source_revision: 1 }
    end)
    played = match
    played.update!(stats: { "teams" => [ { "summoned" => [ 1, 9 ], "used" => [ 2 ], "max_chain" => 3, "spells" => 1 }, {} ],
                            "state" => { "last_hit" => { "team" => 0, "exact" => true, "code" => 3 }, "turn_lp" => [ 8000, 8000 ] } })
    surrender(played)

    assert_equal [ "Corrente de 3 elos", "Invocou Gate Guardian", "Usou Illusion Gate" ],
                 rewards(jaden, played)["lines"].pluck("label") & [ "Corrente de 3 elos", "Invocou Gate Guardian", "Usou Illusion Gate" ]
  end

  it "quem apagou a conta fica de fora" do
    played = match
    syrus.destroy!
    surrender(played)

    assert_nil played.players.find_by(team: 1).rewards
    assert_equal 194, rewards(jaden, played)["total"]
  end
end
