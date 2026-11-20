require "test_helper"

class Economy::MissionsTest < ActiveSupport::TestCase
  SUNDAY = Time.zone.local(2026, 11, 15, 12)
  PRIZES = [ "Toon Kingdom", "Gemini Summoner", "Illusion Gate", "Sabatiel - The Philosopher's Stone", "Raigeki", "Pot of Greed", "Monster Reborn" ].freeze

  let(:user) { User.create!(email: "jaden@example.com", password: "duelista123", nickname: "Jaden", age_group: "18+") }
  let(:missions) { Economy::Missions.new(user) }

  before do
    Card.insert_all!(PRIZES.each_with_index.map { |name, code| { engine_code: code + 1, name:, card_type: "Spell", monster_types: [], source_revision: 1 } })
  end

  # Uma partida terminada do jogador (time 0): vitória que conta, vitória que não conta ou derrota.
  def played(result = :win, at: Time.current)
    match = Match.create!(mode: "1x1", banlist: true, destiny_draw: false, seed: [ 1, 2, 3, 4 ], started_at: at - 10.minutes, finished_at: at,
                          status: "finished", winner_team: result == :loss ? 1 : 0)
    match.players.create!(user:, team: 0, seat: 0, deck: {}, mission_win: result == :win)
    match
  end

  def award(count = 1, **options) = Array.new(count) { Economy::Missions.new(user).award(played(**options)) }.last
  def state(id) = Economy::Missions.new(user).progress.find { |mission| mission[:id] == id }

  it "o arquivo de missões só fala de cartas e pacotes que existem no jogo" do
    cards = YAML.safe_load_file(Rails.root.join("db/seeds/jogo/cartas.yml")).pluck("nome")
    packs = YAML.safe_load_file(Rails.root.join("db/seeds/jogo/pacotes.yml")).pluck("nome")
    all = Economy::Missions.all

    assert_empty all.flat_map { |mission| [ *mission.dig("premio", "carta_da_vez"), *mission.dig("premio", "carta_sorteada_entre") ] } - cards
    assert_empty all.flat_map { |mission| mission["libera_pacotes"].to_a } - packs
    assert_equal "Torneio Slifer Red", Economy::Missions.name_of("torneio_slifer_red")
  end

  it "torneio: com 10 vitórias libera os pacotes, uma vez só" do
    travel_to(Time.zone.local(2026, 11, 18, 12)) do
      assert_empty award(9, at: 2.days.ago)
      assert_equal({ progress: 9, target: 10, done: false, goal: "Vencer 10 duelos", reward: "Libera Test of Luck e Power of the Heroes na loja" },
                   state("torneio_slifer_red").slice(:progress, :target, :done, :goal, :reward))

      assert_includes award(at: 2.days.ago), { name: "Torneio Slifer Red", card: nil, packs: [ "Test of Luck", "Power of the Heroes" ] }
      assert_empty award(at: 2.days.ago)
      assert_equal [ 10, true, false ], state("torneio_slifer_red").values_at(:progress, :done, :repeats)
      assert_equal [ 11, 30 ], state("torneio_ra_yellow").values_at(:progress, :target)
    end
  end

  it "campeonato de domingo: 5 vitórias no mesmo domingo; as de outro dia não contam" do
    travel_to(SUNDAY - 1.day) { award(5) }
    travel_to(SUNDAY) do
      assert_equal 0, state("campeonato_de_domingo")[:progress]
      assert_empty award(4).pluck(:name) & [ "Campeonato de domingo" ]
      assert_includes award.pluck(:name), "Campeonato de domingo"
    end
  end

  it "carta da semana: 5 vitórias na semana dão a carta da vez, uma por semana, na ordem" do
    travel_to(SUNDAY - 3.days) do
      award(4)
      assert_equal({ name: "Carta da semana", card: "Toon Kingdom", packs: [] }, award.find { |mission| mission[:name] == "Carta da semana" })
      assert_empty award
      assert_equal [ 5, true, true ], state("carta_da_semana").values_at(:progress, :done, :repeats)
    end
    travel_to(SUNDAY + 3.days) do
      assert_equal [ 0, false ], state("carta_da_semana").values_at(:progress, :done)
      assert_equal "Gemini Summoner", award(5).find { |mission| mission[:name] == "Carta da semana" }[:card]
    end
    assert_equal [ 1, 1 ], user.collection_cards.joins(:card).where(cards: { name: [ "Toon Kingdom", "Gemini Summoner" ] }).pluck(:quantity)
  end

  it "visitante do abismo: cada 10 vitórias seguidas dão uma carta sorteada; a derrota zera" do
    travel_to(Time.zone.local(2026, 11, 2, 12)) { award(9) }
    travel_to(Time.zone.local(2026, 11, 3, 12)) do
      played(:loss)
      award(4)
      played(:uncounted)
      assert_equal [ 4, 10 ], state("visitante_do_abismo").values_at(:progress, :target)
    end
    travel_to(Time.zone.local(2026, 11, 4, 12)) do
      assert_empty award(5).pluck(:name) & [ "Visitante do abismo" ]
      prize = award.find { |mission| mission[:name] == "Visitante do abismo" }

      assert_includes PRIZES.last(5), prize[:card]
      assert_equal 0, state("visitante_do_abismo")[:progress]
      assert_match(/\ADá uma carta sorteada entre Illusion Gate, .* e Monster Reborn\z/, state("visitante_do_abismo")[:reward])
    end
  end
end
