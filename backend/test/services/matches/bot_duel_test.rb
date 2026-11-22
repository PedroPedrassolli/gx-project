require "test_helper"

# Duelos inteiros do computador (Bots::Player) contra o robô que escolhe ao acaso, pelo mesmo
# caminho da API (Matches::Game): o computador responde sozinho tudo o que é dele, no mesmo
# pedido da jogada do outro lado. Confere que ele termina os duelos sem desistir e que joga
# melhor que o acaso.
class Matches::BotDuelTest < ActiveSupport::TestCase
  MAX_RESPONSES = 3000
  SEEDS = Rails.root.join("db/seeds/jogo")
  CARDS = YAML.safe_load_file(SEEDS.join("cartas.yml")).index_by { |card| card["nome"] }
  EXCEPTIONS = GameData::Pool.exceptions(SEEDS)
  STARTER = YAML.safe_load_file(Decks::StarterDeck::FILE)["principal"].flat_map { |row| [ row["passcode"] ] * (row["copias"] || 1) }

  before { Duel::Engine.any_instance.expects(:record_error).never }

  # O deck do personagem com os códigos da engine, como a partida guarda.
  def character_deck(id, random)
    codes = ->(cards) { cards.flat_map { |name, copies| [ GameData::Pool.engine_code(CARDS.fetch(name), EXCEPTIONS) ] * copies } }
    deck = Characters::Roster.find(id).deck
    { main: codes.call(deck.main).shuffle(random:), extra: codes.call(deck.extra), destiny: [] }
  end

  # Joga até o fim. bot_team: o lugar do computador (o time 0 começa).
  def play(seed, character:, bot_team:)
    random = Random.new(seed)
    match = Match.create!(mode: "1x1", banlist: false, destiny_draw: false, seed: Array.new(4) { random.rand(2**63) }, started_at: Time.current)
    match.players.create!(team: bot_team, seat: bot_team, character:, deck: character_deck(character, random))
    match.players.create!(team: 1 - bot_team, seat: 1 - bot_team, deck: { main: STARTER.shuffle(random:), extra: [], destiny: [] })
    robot = DuelRobot.new(random, STARTER)
    game = Matches::Game.new(match)
    game.start!
    MAX_RESPONSES.times do
      break unless match.dueling?

      assert_equal 1 - bot_team, match.prompt_team, "semente #{seed}: a pergunta do computador ficou para a tela"
      answer(game, match.prompt_team, game.view(match.prompt_team)[:prompt], robot)
    end
    assert_equal "duel", match.finish_reason, "semente #{seed} (#{character}): o duelo não acabou na engine"
    match.winner_team == bot_team
  end

  def answer(game, team, prompt, robot)
    choice = robot.choose(prompt)
    tries = 0
    begin
      game.respond!(team, choice)
    rescue Duel::Session::InvalidResponse
      tries += 1
      raise "a engine recusou #{choice} em #{prompt}" unless prompt[:type] == "announce_card" && tries < 50

      choice = robot.choose(prompt)
      retry
    end
  end

  it "vence o robô que joga ao acaso na maioria dos duelos" do
    wins = (1..6).count { |seed| play(seed, character: "yugi", bot_team: seed % 2) }

    assert_operator wins, :>=, 5, "o computador venceu só #{wins} de 6"
  end

  it "termina o duelo com o deck de cada personagem, sem desistir" do
    Characters::Roster.all.each_with_index do |character, index|
      play(100 + index, character: character.id, bot_team: index % 2)
    end
  end

  # O replay refaz a partida só com as respostas gravadas: se o computador escolhesse algo que
  # não fica no log, o duelo refeito terminaria diferente. O do Yugi é longo (dezenas de turnos).
  it "o replay refaz o duelo contra o computador até o fim, com os mesmos pontos de vida" do
    play(102, character: "yugi", bot_team: 1)
    match = Match.last
    replay = Matches::Replay.new(match)
    last = replay.frames(0, replay.turns).last[:view]

    assert_equal Matches::Game.new(match).view(0)[:sides].pluck(:lp), last[:sides].pluck(:lp)
  end
end
