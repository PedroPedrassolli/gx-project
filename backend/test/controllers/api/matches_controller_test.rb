require "test_helper"

class Api::MatchesControllerTest < ActionDispatch::IntegrationTest
  include StarterDeckCards

  def player(name) = User.create!(email: "#{name.downcase}@example.com", password: "duelista123", nickname: name, age_group: "18+")

  def session_for(user)
    open_session.tap { |session| session.post api_session_path, params: { email: user.email, password: "duelista123" }, as: :json }
  end

  let(:jaden) { player("Jaden") }
  let(:syrus) { player("Syrus") }
  # A partida começa como no jogo: sala, decks iniciais e os dois prontos.
  let(:match) do
    load_starter_deck_cards
    room = Room.create!(owner: jaden, code: "ABC234")
    [ jaden, syrus ].each_with_index do |user, seat|
      Decks::StarterDeck.give_to(user)
      room.players.create!(user:, seat:, deck: user.decks.sole, ready: true)
    end
    Matches::Start.new(room).call
  end
  # Quem começa saiu no sorteio.
  let(:first) { User.find(match.players.find_by!(team: 0).user_id) }
  let(:second) { User.find(match.players.find_by!(team: 1).user_id) }

  def answer(session, response, seq: match.reload.responses.count)
    session.post responses_api_match_path(match), params: { seq:, response: }, as: :json
  end

  before { Realtime::Publisher.current.clear }

  it "mostra a mesa só para quem joga, com a pergunta para quem responde" do
    session = session_for(first)
    session.get api_match_path(match)
    data = session.response.parsed_body["data"]
    assert_equal [ "dueling", 0, "select_idlecmd" ], [ data["status"], data["you"], data.dig("view", "prompt", "type") ]
    assert_equal %w[Jaden Syrus], data["players"].pluck("nickname").sort

    other = session_for(second)
    other.get api_match_path(match)
    assert_equal [ nil, 0 ], other.response.parsed_body.dig("data", "view").values_at("prompt", "waiting_for")

    outsider = session_for(player("Chazz"))
    outsider.get api_match_path(match)
    assert_equal 404, outsider.response.status
  end

  it "a resposta avança o duelo e o outro recebe a mesa nova" do
    session = session_for(first)
    answer(session, { command: "end" })

    data = session.response.parsed_body["data"]
    assert_equal [ 200, 1, 2 ], [ session.response.status, data.dig("view", "waiting_for"), data.dig("view", "turn") ]
    update = Realtime::Publisher.current.events_for(second.id).sole
    assert_equal [ "duel.updated", 1, data["seq"] ], [ update.name, update.data[:you], update.data[:seq] ]
    assert_equal "select_idlecmd", update.data.dig(:view, :prompt, :type).to_s
  end

  it "sem o Ably no ar, a jogada vale do mesmo jeito" do
    Realtime::MemoryPublisher.any_instance.stubs(:publish).raises(Realtime::AblyPublisher::Error, "sem conexão")
    session = session_for(first)
    answer(session, { command: "end" })

    assert_equal [ 200, 2 ], [ session.response.status, match.reload.turn ]
  end

  it "resposta com a mesa velha ou fora da vez dá 409, e a jogada que não vale dá 422" do
    session = session_for(first)
    answer(session, { command: "end" }, seq: 0)
    assert_equal [ 409, "A mesa mudou: confira e jogue de novo." ], [ session.response.status, session.response.parsed_body.dig("error", "message") ]

    other = session_for(second)
    answer(other, { command: "end" })
    assert_equal [ 409, "Não é a sua vez." ], [ other.response.status, other.response.parsed_body.dig("error", "message") ]

    # Quem não joga a partida nem fica sabendo que ela existe.
    outsider = session_for(player("Chazz"))
    answer(outsider, { command: "end" })
    assert_equal 404, outsider.response.status

    before = match.reload.responses.count
    [ { command: "summon", index: 59 }, { command: "voar" } ].each do |response|
      answer(session, response)
      assert_equal [ 422, "Essa jogada não vale agora." ], [ session.response.status, session.response.parsed_body.dig("error", "message") ]
    end
    assert_equal before, match.reload.responses.count
  end

  it "a mesa traz o relógio: o prazo da pergunta, o banco do turno e o fim do duelo" do
    session = session_for(first)
    session.get api_match_path(match)
    data = session.response.parsed_body["data"]

    assert_equal [ match.deadline_at.iso8601, 300, (match.started_at + 60.minutes).iso8601, "ABC234" ],
                 data.values_at("deadline_at", "turn_time_left", "ends_at", "room_code")
  end

  it "sala sem limite: a mesa vem sem prazo e sem fim do duelo" do
    match.update!(decision_seconds: nil, duel_minutes: nil, deadline_at: nil, turn_time_left: 0)
    session = session_for(first)
    session.get api_match_path(match)

    assert_equal [ nil, 0, nil ], session.response.parsed_body["data"].values_at("deadline_at", "turn_time_left", "ends_at")
  end

  it "prazo vencido: a próxima consulta encerra a partida e o outro fica sabendo" do
    travel_to(match.deadline_at + 1.second) do
      session = session_for(second)
      session.get api_match_path(match)

      assert_equal [ "finished", 1, "timeout" ], session.response.parsed_body["data"].values_at("status", "winner_team", "finish_reason")
      assert_equal "duel.updated", Realtime::Publisher.current.events_for(first.id).sole.name
    end
  end

  it "resposta depois do prazo: 409, e a partida já acabou" do
    travel_to(match.deadline_at + 1.second) do
      session = session_for(first)
      answer(session, { command: "end" })

      assert_equal [ 409, "O tempo acabou." ], [ session.response.status, session.response.parsed_body.dig("error", "message") ]
      assert_equal "finished", match.reload.status
    end
  end

  it "o replay abre depois do fim, só para quem jogou, um turno por vez" do
    session = session_for(first)
    session.get replay_api_match_path(match)
    assert_equal [ 409, "O replay fica pronto quando o duelo acaba." ], [ session.response.status, session.response.parsed_body.dig("error", "message") ]

    session.post surrender_api_match_path(match), as: :json
    session.get replay_api_match_path(match, turn: 99)
    data = session.response.parsed_body["data"]
    assert_equal [ 200, 1, 1, 0, "surrender" ], [ session.response.status, data["turn"], data["turns"], data["you"], data["finish_reason"] ]
    assert_equal [ 1 ], data["frames"].map { |frame| frame.dig("view", "turn") }.uniq
    # A partida acabada não muda: o navegador guarda por um dia.
    assert_equal "max-age=86400, private", session.response.headers["Cache-Control"]

    outsider = session_for(player("Chazz"))
    outsider.get replay_api_match_path(match)
    assert_equal 404, outsider.response.status
    # Turno que não é número (até um hash na URL) cai no primeiro, sem erro 500.
    session.get "#{replay_api_match_path(match)}?turn[a]=1"
    assert_equal [ 200, 1 ], [ session.response.status, session.response.parsed_body.dig("data", "turn") ]
  end

  it "a frase vai para o outro na hora, aparece na mesa por alguns segundos e tem limite" do
    session = session_for(first)
    session.post emotes_api_match_path(match), params: { emote: "nice" }, as: :json
    assert_equal [ 200, "nice", 0 ], [ session.response.status, *session.response.parsed_body["data"].values_at("emote", "team") ]
    event = Realtime::Publisher.current.events_for(second.id).sole
    assert_equal [ "duel.emote", match.id, "nice" ], [ event.name, *event.data.values_at(:id, :emote) ]

    session.post emotes_api_match_path(match), params: { emote: "gg" }, as: :json
    assert_equal [ 429, "Uma frase a cada 3 segundos." ], [ session.response.status, session.response.parsed_body.dig("error", "message") ]

    other = session_for(second)
    emote = lambda do
      other.get api_match_path(match)
      other.response.parsed_body.dig("data", "players").find { |player| player["team"] == 0 }["emote"]
    end
    assert_equal "nice", emote.call
    travel(10.seconds) { assert_nil emote.call }
  end

  it "frase que não existe não sai, e sem o Ably no ar a frase vale do mesmo jeito" do
    session = session_for(first)
    session.post emotes_api_match_path(match), params: { emote: "palavrão" }, as: :json
    assert_equal [ 422, "Essa frase não existe." ], [ session.response.status, session.response.parsed_body.dig("error", "message") ]

    Realtime::MemoryPublisher.any_instance.stubs(:publish).raises(Realtime::AblyPublisher::Error, "sem conexão")
    session.post emotes_api_match_path(match), params: { emote: "hello" }, as: :json
    assert_equal [ 200, "hello" ], [ session.response.status, match.players.find_by!(team: 0).emote ]
  end

  it "'sempre perguntar' fica guardado no jogador e volta na mesa" do
    session = session_for(first)
    session.post settings_api_match_path(match), params: { always_chain: true }, as: :json
    assert_equal [ 204, true ], [ session.response.status, match.players.find_by!(team: 0).always_chain ]

    session.get api_match_path(match)
    assert_equal true, session.response.parsed_body.dig("data", "always_chain")
    session.post settings_api_match_path(match), params: {}, as: :json
    assert_equal false, match.players.find_by!(team: 0).always_chain
  end

  it "no fim, a mesa traz o DP do duelo de quem consulta; durante o duelo, nada" do
    session = session_for(second)
    session.get api_match_path(match)
    assert_nil session.response.parsed_body.dig("data", "rewards")

    session.post surrender_api_match_path(match), as: :json
    rewards = session.response.parsed_body.dig("data", "rewards")
    assert_equal [ 10, [ "short" ], 10 ], [ rewards["total"], rewards["cuts"].pluck("key"), rewards["balance"] ]
  end

  it "desistir encerra a partida e avisa o outro; depois do fim, não dá mais" do
    session = session_for(first)
    session.post surrender_api_match_path(match), as: :json

    assert_equal [ "finished", 1, "surrender" ], session.response.parsed_body["data"].values_at("status", "winner_team", "finish_reason")
    assert_equal "duel.updated", Realtime::Publisher.current.events_for(second.id).sole.name
    session.post surrender_api_match_path(match), as: :json
    assert_equal 409, session.response.status

    outsider = session_for(player("Chazz"))
    outsider.post surrender_api_match_path(match), as: :json
    assert_equal 404, outsider.response.status
  end
end
