require "test_helper"

class Matches::GameTest < ActiveSupport::TestCase
  include StarterDeckCards

  def player(name) = User.create!(email: "#{name.downcase}@example.com", password: "duelista123", nickname: name, age_group: "18+")

  let(:room) { Room.create!(owner: player("Jaden"), code: "ABC234") }
  let(:match) do
    load_starter_deck_cards
    [ room.owner, player("Syrus") ].each_with_index do |user, seat|
      Decks::StarterDeck.give_to(user)
      room.players.create!(user:, seat:, deck: user.decks.sole, ready: true)
    end
    Matches::Start.new(room).call
  end

  it "ao começar, guarda o turno, a fase e a primeira pergunta de verdade" do
    assert_equal [ 1, 0, 0x04, "select_idlecmd", 0 ], [ match.turn, match.turn_team, match.phase, match.prompt["type"], match.prompt_team ]
  end

  it "passa sozinho pelas cadeias sem opção e grava essas respostas" do
    assert_operator match.responses.count, :>, 0
    assert(match.responses.all? { |response| response.bytes == Matches::Game::PASS })
  end

  it "põe a carta sozinha na zona livre do centro, sem perguntar a zona" do
    chamberlain = 44_430_454 # monstro normal de nível 3, do deck inicial
    match = Match.create!(mode: "1x1", banlist: true, destiny_draw: false, seed: [ 1, 2, 3, 4 ], started_at: Time.current)
    2.times { |team| match.players.create!(team:, seat: team, deck: { main: [ chamberlain ] * 40, extra: [] }) }
    Matches::Game.new(match).start!
    game = Matches::Game.new(match.reload)
    game.respond!(0, { command: "summon", index: 0 })

    assert_equal "select_idlecmd", match.reload.prompt["type"]
    assert_equal chamberlain, game.view(0)[:sides][0][:monsters][2][:code]
    assert_includes match.responses.map(&:bytes), [ 0, 0x04, 2 ].pack("C*")
  end

  # Partida com decks vazios, para testar só o que a partida faz com as mensagens.
  def empty_match
    match = Match.create!(mode: "1x1", banlist: true, destiny_draw: false, seed: [ 1, 2, 3, 4 ], started_at: Time.current)
    2.times { |team| match.players.create!(team:, seat: team, deck: { main: [], extra: [] }) }
    match
  end

  it "a pergunta guarda a dica do que escolher" do
    match = empty_match
    hint = Duel::MessageParser::Message.new(type: Duel::MessageParser::HINT, payload: [ 3, 0, 502 ].pack("CCQ<"))
    select_card = Duel::MessageParser::Message.new(type: 15, payload: [ 0, 0, 1, 1, 0 ].pack("CCL<L<L<"))
    Duel::Session.any_instance.stubs(:start).returns([ hint, select_card ])
    Matches::Game.new(match).start!

    assert_equal [ "select_card", 502 ], match.reload.prompt.values_at("type", "hint")
  end

  it "a mensagem de vitória encerra a partida; empate fica sem vencedor" do
    [ [ 1, 1 ], [ 2, nil ] ].each do |player, winner|
      match = empty_match
      win = Duel::MessageParser::Message.new(type: Duel::MessageParser::WIN, payload: [ player, 0 ].pack("CC"))
      Duel::Session.any_instance.stubs(:start).returns([ win ])
      Duel::Session.any_instance.stubs(:finished?).returns(true)
      Matches::Game.new(match).start!

      assert_equal [ "finished", winner, nil ], [ match.reload.status, match.winner_team, match.prompt ]
    end
  end

  it "a mesa de cada time vem da engine, com a pergunta só para quem responde" do
    game = Matches::Game.new(match.reload)
    first, second = [ 0, 1 ].map { |team| game.view(team) }

    assert_equal "select_idlecmd", first.dig(:prompt, :type)
    assert_nil second[:prompt]
    assert_equal first[:sides][0][:hand].size, second[:sides][0][:hand].count { |card| card[:hidden] }
  end
end
