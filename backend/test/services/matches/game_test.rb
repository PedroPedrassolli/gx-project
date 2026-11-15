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

  def engine_message(type, payload) = Duel::MessageParser::Message.new(type:, payload: payload.b)
  # A corrente com o Painful Choice (74191942) no elo 1 e uma pergunta para terminar.
  let(:chaining) { engine_message(70, [ 74191942, 1, 8, 0, 1, 1, 8, 0, 74191942 << 20, 1 ].pack("L<CCL<L<CCL<Q<L<")) }
  let(:select_card) { engine_message(15, [ 0, 0, 1, 1, 0 ].pack("CCL<L<L<")) }

  it "guarda os eventos numerados e a corrente aberta, com o elo negado marcado" do
    match = empty_match
    turn = engine_message(Duel::MessageParser::NEW_TURN, [ 0 ].pack("C"))
    Duel::Session.any_instance.stubs(:start).returns([ turn, chaining, engine_message(75, [ 1 ].pack("C")), select_card ])
    Matches::Game.new(match).start!

    match.reload
    assert_equal [ [ 1, "turn" ], [ 2, "chain" ], [ 3, "chain_negated" ] ], match.events.map { |event| event.values_at("id", "type") }
    assert_equal [ [ 74191942, 1, true ] ], match.chain.map { |link| link.values_at("code", "link", "negated") }
  end

  it "o ataque guarda o código das cartas com a face para cima, lido da mesa na hora" do
    chamberlain = 44_430_454 # monstro normal de nível 3, do deck inicial
    match = Match.create!(mode: "1x1", banlist: true, destiny_draw: false, seed: [ 1, 2, 3, 4 ], started_at: Time.current)
    2.times { |team| match.players.create!(team:, seat: team, deck: { main: [ chamberlain ] * 40, extra: [] }) }
    Matches::Game.new(match).start!
    game = Matches::Game.new(match.reload)
    [ [ 0, { command: "summon", index: 0 } ], [ 0, { command: "end" } ], [ 1, { command: "summon", index: 0 } ],
      [ 1, { command: "battle" } ], [ 1, { command: "attack", index: 0 } ], [ 1, { indexes: [ 0 ] } ] ].each { |team, choice| game.respond!(team, choice) }

    attack = match.reload.events.find { |event| event["type"] == "attack" }
    assert_equal [ chamberlain, chamberlain ], [ attack.dig("attacker", "code"), attack.dig("target", "code") ]
  end

  it "a corrente resolvida sai da pilha e o log fica com os últimos eventos" do
    match = empty_match
    phases = Array.new(55) { engine_message(Duel::MessageParser::NEW_PHASE, [ 0x04 ].pack("S<")) }
    solved = [ engine_message(73, [ 1 ].pack("C")), engine_message(74, "") ]
    Duel::Session.any_instance.stubs(:start).returns([ chaining, *solved, *phases, select_card ])
    Matches::Game.new(match).start!

    match.reload
    assert_equal [ [], 58, Matches::Game::MAX_EVENTS, 9 ], [ match.chain, match.events_count, match.events.size, match.events.first["id"] ]
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
