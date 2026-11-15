require "test_helper"

# Duelos inteiros, do começo ao fim, pelo mesmo caminho da API (Matches::Game), com um robô
# escolhendo ao acaso entre as opções que a engine oferece (GXP-64). Pega a jogada válida que
# a engine recusa, a pergunta sem tela, o erro de script e a carta escondida que aparece para
# o outro. Para jogar mais duelos com decks sorteados do catálogo: ROBOT_DUELS=50.
class Matches::RobotDuelTest < ActiveSupport::TestCase
  EXTRA_TYPES = %w[Fusion Synchro].freeze
  MAX_RESPONSES = 3000

  # Os códigos do catálogo do jogo, para os decks sorteados e para declarar nome de carta.
  CATALOG = YAML.safe_load_file(Rails.root.join("db/seeds/jogo/cartas.yml")).select { |card| card["passcode"] }
  MAIN = CATALOG.reject { |card| card["tipos"].to_a.intersect?(EXTRA_TYPES) }.pluck("passcode")
  EXTRA = CATALOG.select { |card| card["tipos"].to_a.intersect?(EXTRA_TYPES) }.pluck("passcode")
  STARTER = YAML.safe_load_file(Decks::StarterDeck::FILE)["principal"].flat_map { |row| [ row["passcode"] ] * (row["copias"] || 1) }

  before { Duel::Engine.any_instance.expects(:record_error).never }

  def starter_decks(random) = Array.new(2) { { main: STARTER.shuffle(random:), extra: [], destiny: [] } }

  def catalog_decks(random)
    Array.new(2) { { main: MAIN.sample(40, random:), extra: EXTRA.sample(random.rand(0..15), random:), destiny: [] } }
  end

  # Joga até alguém vencer, conferindo a mesa dos dois lados a cada pergunta.
  def play(seed, &decks)
    random = Random.new(seed)
    match = Match.create!(mode: "1x1", banlist: false, destiny_draw: false, seed: Array.new(4) { random.rand(2**63) }, started_at: Time.current)
    decks.call(random).each_with_index { |deck, team| match.players.create!(team:, seat: team, deck:) }
    robot = DuelRobot.new(random, MAIN)
    game = Matches::Game.new(match)
    game.start!
    MAX_RESPONSES.times do
      break unless match.dueling?

      team = match.prompt_team
      views = [ game.view(0), game.view(1) ]
      assert_nothing_hidden_shown(views, seed)
      answer(game, team, views[team][:prompt], robot, seed)
    end
    assert_equal "finished", match.status, "semente #{seed}: o duelo não acabou em #{MAX_RESPONSES} respostas"
    robot.seen
  end

  # Só o nome de carta o robô não sabe se vale (a engine confere os opcodes): tenta outro.
  def answer(game, team, prompt, robot, seed)
    choice = robot.choose(prompt)
    tries = 0
    begin
      game.respond!(team, choice)
    rescue Duel::Session::InvalidResponse
      tries += 1
      raise "semente #{seed}: a engine recusou #{choice} em #{prompt}" unless prompt[:type] == "announce_card" && tries < 50

      choice = robot.choose(prompt)
      retry
    end
  end

  # Do outro lado: a mão só com as cartas reveladas (o dono vê public), nada do Extra e nada
  # da carta virada no campo. A pergunta só vai para quem responde.
  def assert_nothing_hidden_shown(views, seed)
    views.each_with_index do |view, viewer|
      other = view[:sides][1 - viewer]
      owner_hand = views[1 - viewer][:sides][1 - viewer][:hand]
      other[:hand].each_with_index do |card, index|
        assert(card == { hidden: true } || owner_hand[index] == card.merge(public: true), "semente #{seed}: mão do outro à vista")
      end
      assert_not other.key?(:extra_cards), "semente #{seed}: Extra do outro à vista"
      field = (other[:monsters] + other[:spells] + [ other[:field_spell] ]).compact
      assert(field.none? { |card| card[:face_down] && card.key?(:code) }, "semente #{seed}: carta virada do outro à vista")
      view[:events].each { |event| assert_event_hidden(event, viewer, seed) }
    end
    assert_equal 1, views.count { |view| view.key?(:prompt) }, "semente #{seed}: a pergunta tem de ir para um só"
  end

  # No log, do outro lado: a compra sem as cartas, a carta baixada sem código e a carta que
  # muda de lugar ou de posição só com código quando estava ou fica à vista.
  def assert_event_hidden(event, viewer, seed)
    public = ->(place) { place[:location] == 0x10 || ([ 0x04, 0x08, 0x20, 0x40 ].include?(place[:location]) && place[:position].anybits?(0x5)) }
    hidden = case event[:type]
    when "draw" then event[:team] != viewer && event.key?(:codes)
    when "set" then event[:controller] != viewer && event[:code].positive?
    when "move"
      places = event.values_at(:from, :to)
      event[:code].positive? && places.none? { |place| place[:controller] == viewer || public.call(place) }
    when "position" then event[:controller] != viewer && event[:code].positive? && !(event[:from] | event[:to]).anybits?(0x5)
    when "attack" then event.values_at(:attacker, :target).compact.any? { |place| place[:code] && !place[:position].anybits?(0x5) }
    end
    assert_not hidden, "semente #{seed}: o log mostra ao time #{viewer} uma carta escondida: #{event}"
  end

  it "joga duelos inteiros com o deck inicial nos dois lados" do
    seen = [ 1, 2 ].map { |seed| play(seed) { |random| starter_decks(random) } }.reduce { |all, counts| all.merge(counts) { |_, a, b| a + b } }

    assert_operator seen.keys.size, :>=, 5, "poucos tipos de pergunta: #{seen}"
  end

  it "joga duelos inteiros com decks sorteados do catálogo" do
    count = ENV.fetch("ROBOT_DUELS", "4").to_i
    seen = (1..count).map { |seed| play(1000 + seed) { |random| catalog_decks(random) } }.reduce { |all, counts| all.merge(counts) { |_, a, b| a + b } }

    puts "\nPerguntas nos duelos do robô: #{seen.sort_by { -_2 }.to_h}" if ENV["ROBOT_DUELS"]
    assert_operator seen.keys.size, :>=, 6, "poucos tipos de pergunta: #{seen}"
  end
end
