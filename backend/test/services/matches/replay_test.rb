require "test_helper"

class Matches::ReplayTest < ActiveSupport::TestCase
  CHAMBERLAIN = 44_430_454 # monstro normal de nível 3, do deck inicial

  # Partida previsível (semente fixa, o mesmo monstro nos dois decks): cada um invoca um
  # monstro, e o segundo desiste no turno 2.
  let(:match) do
    match = Match.create!(mode: "1x1", banlist: true, destiny_draw: false, seed: [ 1, 2, 3, 4 ], started_at: Time.current)
    2.times { |team| match.players.create!(team:, seat: team, deck: { main: [ CHAMBERLAIN ] * 40, extra: [] }) }
    Matches::Game.new(match).start!
    game = Matches::Game.new(match.reload)
    [ [ 0, { command: "summon", index: 0 } ], [ 0, { command: "end" } ], [ 1, { command: "summon", index: 0 } ] ].each do |team, choice|
      game.respond!(team, choice)
    end
    game.surrender!(1)
    match.reload
  end

  it "refaz o duelo turno a turno, com a mesa de quem assiste, sem tocar nas engines dos duelos" do
    replay = Matches::Replay.new(match)
    engines = Duel::Session::CACHE.size
    first = replay.frames(0, 1)

    assert_equal 2, replay.turns
    assert(first.all? { |frame| frame[:view][:turn] == 1 })
    assert_includes first.first[:view][:events].pluck(:type), "turn"
    assert_equal CHAMBERLAIN, first.last[:view][:sides][0][:monsters][2][:code]
    # A mão do outro continua escondida no replay.
    assert(first.last[:view][:sides][1][:hand].all? { |card| card[:hidden] })
    assert_equal engines, Duel::Session::CACHE.size
  end

  it "o turno pedido traz só os quadros dele, vistos pelo time de quem assiste" do
    second = Matches::Replay.new(match).frames(1, 2)

    assert(second.all? { |frame| frame[:view][:turn] == 2 && frame[:view][:you] == 1 })
    assert_includes second.flat_map { |frame| frame[:view][:events].pluck(:type) }, "summon"
    assert_operator second.first[:step], :>, 0
  end
end
