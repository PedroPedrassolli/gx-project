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
    # Os prêmios do GX Project e, como ninguém jogou nada, os bônus de vencer sem magia, sem
    # armadilha e sem Invocação-Especial (15, 15 e 10).
    assert_equal({ "prize" => 300, "win_prize" => 200, "level" => 2, "turns" => 12, "network_win" => 50, "duelist" => 90,
                   "no_spells" => 15, "no_traps" => 15, "no_special" => 10 },
                 won["lines"].to_h { |line| line.values_at("key", "dp") })
    # 694 DP sobem o Jaden para o nível 3 (a cada 300), e cada nível novo paga 100.
    assert_equal [ 894, [], 894, 3 ], won.values_at("total", "cuts", "balance", "level")
    # Quem perde leva o prêmio do duelo e os bônus de sempre: dá para uns três pacotes.
    assert_equal({ "prize" => 300, "level" => 2, "loss" => 10, "turns" => 6 }, rewards(syrus, played)["lines"].to_h { |line| line.values_at("key", "dp") })
    assert_equal [ 418, 418, 2 ], rewards(syrus, played).values_at("total", "balance", "level")
    assert_equal [ [ "duel", "partida:#{played.id}", 694 ], [ "level_up", "nivel:3", 200 ] ],
                 jaden.dp_transactions.order(:id).map { |line| [ line.reason, line.key, line.amount ] }
  end

  it "duelo curto paga só 10, e jogar de novo com a mesma pessoa no dia paga tudo" do
    surrender(match(turns: 2))
    assert_equal [ 10, [ "short" ] ], rewards(jaden, Match.last).then { |data| [ data["total"], data["cuts"].pluck("key") ] }

    # O 4º duelo do dia contra o Syrus paga a soma inteira das linhas, sem corte.
    3.times { surrender(match) }
    data = rewards(jaden, Match.last)
    assert_equal [ [], data["lines"].sum { |line| line["dp"] } ], [ data["cuts"], data["total"] - data["level_ups"].sum { |line| line["dp"] } ]
  end

  it "o DP de duelo sobe o nível, cada nível novo paga 100, e esse DP não conta para o nível" do
    jaden.update!(dp_earned: 290)
    played = match
    surrender(played)

    # 290 + 694 = 984 DP ganhos: nível 4, três níveis de uma vez.
    assert_equal [ { "key" => "level_up", "label" => "Subiu para o nível 4", "dp" => 300 } ], rewards(jaden, played)["level_ups"]
    assert_equal [ 994, 4, 994, 984 ], [ rewards(jaden, played)["total"], jaden.reload.level, Economy::Ledger.balance(jaden), jaden.dp_earned ]
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

  it "os desafios concluídos ficam com o jogador, aparecem no resultado e pagam 2 DP cada, em todo duelo" do
    played = match
    played.update!(stats: { "teams" => [ { "battle_damage" => 10_000, "max_chain" => 5 }, {} ], "state" => { "turn_lp" => [ 8000, 8000 ] } })
    surrender(played)

    assert_equal [ { "number" => 1, "label" => "Causar 10.000 ou mais de dano de batalha num duelo" }, { "number" => 21, "label" => "Formar uma corrente de 5 elos" } ],
                 rewards(jaden, played)["challenges"]
    assert_equal [ [ 1, played.id ], [ 21, played.id ] ], jaden.user_challenges.order(:number).pluck(:number, :match_id)
    assert_includes rewards(jaden, played)["lines"], { "key" => "challenges", "label" => "Desafios concluídos (2)", "dp" => 4 }
    assert_empty rewards(syrus, played)["challenges"]

    surrender(match)
    assert_empty rewards(jaden, Match.last)["challenges"]
    assert_equal 4, rewards(jaden, Match.last)["lines"].find { |line| line["key"] == "challenges" }["dp"]
  end

  it "os desafios de vencer olham o deck usado e só valem na vitória da engine" do
    played = match
    surrender(played)
    assert_empty jaden.user_challenges

    again = match
    again.update!(status: "finished", winner_team: 0, finish_reason: "duel", win_reason: 1, finished_at: Time.current)
    Economy::DuelRewards.new(again, [ { lp: 8000, deck: 30 }, { lp: 0, deck: 30 } ]).call

    # Sem dano sofrido (27), em 6 turnos (31), com o deck inicial, que só tem monstros Guerreiro
    # (83) e nenhuma carta da banlist (99), e sem tributo nem invocação (101 a 103).
    assert_equal [ 27, 31, 83, 99, 101, 102, 103 ], jaden.user_challenges.order(:number).pluck(:number)
    assert_empty syrus.user_challenges
  end

  it "a vitória conta para missão sempre que o duelo não é curto, mesmo contra a mesma pessoa" do
    Economy::Missions.any_instance.expects(:award).times(4).returns([ { name: "Torneio Slifer Red", card: nil, packs: [ "Test of Luck" ] } ])
    surrender(match(turns: 2))
    assert_equal [ false, [] ], [ Match.last.players.find_by!(user: jaden).mission_win, rewards(jaden, Match.last)["missions"] ]

    4.times { surrender(match) }
    assert_equal [ true, false ], Match.last.players.order(:team).pluck(:mission_win)
    assert_equal [ { "name" => "Torneio Slifer Red", "card" => nil, "packs" => [ "Test of Luck" ] } ], rewards(jaden, Match.last)["missions"]
  end

  it "quem apagou a conta fica de fora" do
    played = match
    syrus.destroy!
    surrender(played)

    assert_nil played.players.find_by(team: 1).rewards
    assert_equal 894, rewards(jaden, played)["total"]
  end
end
