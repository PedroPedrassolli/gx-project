require "test_helper"

class Api::RoomsControllerTest < ActionDispatch::IntegrationTest
  include StarterDeckCards

  def player(name) = User.create!(email: "#{name.downcase}@example.com", password: "duelista123", nickname: name, age_group: "18+")

  # Cada jogador numa sessão própria do navegador.
  def session_for(user)
    open_session.tap { |session| session.post api_session_path, params: { email: user.email, password: "duelista123" }, as: :json }
  end

  def room_for(owner, **options) = Room.create!(owner:, code: Room.new_code, **options).tap { |room| room.players.create!(user: owner, seat: 0) }

  def events(user) = Realtime::Publisher.current.events_for(user.id)

  let(:jaden) { player("Jaden") }
  let(:syrus) { player("Syrus") }

  before { Realtime::Publisher.current.clear }

  it "pede login" do
    get api_rooms_path

    assert_response :unauthorized
  end

  it "cria a sala com as opções e senta o dono no primeiro lugar" do
    owner = session_for(jaden)
    owner.post api_rooms_path, params: { public: false, banlist: false, destiny_draw: false }, as: :json

    assert_equal 201, owner.response.status
    data = owner.response.parsed_body["data"]
    assert_match(/\A[A-HJ-NP-Z2-9]{6}\z/, data["code"])
    assert_equal [ false, false, false, "waiting", 2, jaden.id ], data.values_at("public", "banlist", "destiny_draw", "status", "seats", "owner_id")
    assert_equal [ { "seat" => 0, "user_id" => jaden.id, "nickname" => "Jaden", "ready" => false, "deck_chosen" => false } ], data["players"]
  end

  it "lista as salas públicas esperando gente, sem as privadas e as paradas há mais de 1 hora" do
    first = room_for(jaden)
    second = room_for(syrus)
    room_for(player("Chazz"), public: false)
    room_for(player("Alexis")).update_columns(updated_at: 2.hours.ago)

    session = session_for(player("Bastion"))
    session.get api_rooms_path

    assert_equal [ second.code, first.code ], session.response.parsed_body["data"].pluck("code")
    assert_equal({ "code" => first.code, "owner" => "Jaden", "players" => 1, "seats" => 2, "banlist" => true, "destiny_draw" => true },
                 session.response.parsed_body["data"].last)
  end

  it "entra no primeiro lugar livre, avisa os dois e esconde o deck do outro" do
    room = room_for(jaden)
    room.players.first.update!(deck: jaden.decks.create!(name: "Heróis"))
    session_for(syrus).tap { |guest| guest.post join_api_room_path(room.code.downcase), as: :json }

    assert_equal [ 0, 1 ], room.players.reload.map(&:seat)
    owner_view = events(jaden).sole.data[:players].first
    guest_view = events(syrus).sole.data[:players].first
    assert_equal [ "room.updated", true, jaden.decks.sole.id ], [ events(jaden).sole.name, owner_view[:deck_chosen], owner_view[:deck_id] ]
    assert_equal [ true, nil ], [ guest_view[:deck_chosen], guest_view[:deck_id] ]
  end

  it "quem já está na sala continua no mesmo lugar, e a sala cheia não aceita mais ninguém" do
    room = room_for(jaden)
    guest = session_for(syrus)
    2.times { guest.post join_api_room_path(room.code), as: :json }
    assert_equal [ jaden.id, syrus.id ], room.players.reload.map(&:user_id)

    late = session_for(player("Chazz"))
    late.post join_api_room_path(room.code), as: :json

    assert_equal [ 422, "A sala está cheia." ], [ late.response.status, late.response.parsed_body.dig("error", "message") ]
  end

  it "entrar ou criar outra sala tira o jogador da anterior" do
    first = room_for(jaden)
    guest = session_for(syrus)
    guest.post join_api_room_path(first.code), as: :json
    guest.post api_rooms_path, as: :json

    assert_equal [ jaden.id ], first.players.reload.map(&:user_id)
    assert_equal syrus.id, Room.find_by!(code: guest.response.parsed_body.dig("data", "code")).owner_id
  end

  it "sai da sala; se o dono sai, a sala fecha e avisa quem ficou" do
    room = room_for(jaden)
    room.players.create!(user: syrus, seat: 1)
    session_for(syrus).post leave_api_room_path(room.code), as: :json

    assert_equal [ jaden.id ], room.players.reload.map(&:user_id)
    room.players.create!(user: syrus, seat: 1)
    session_for(jaden).post leave_api_room_path(room.code), as: :json

    assert_not Room.exists?(room.id)
    assert_equal [ "room.closed", { code: room.code } ], [ events(syrus).last.name, events(syrus).last.data ]
  end

  describe "pronto" do
    before { load_starter_deck_cards }

    it "fica pronto com um deck válido, e o outro só vê que escolheu" do
      room = room_for(jaden)
      room.players.create!(user: syrus, seat: 1)
      Decks::StarterDeck.give_to(jaden)
      deck = jaden.decks.sole
      session = session_for(jaden)
      session.post ready_api_room_path(room.code), params: { deck_id: deck.id, ready: true }, as: :json

      assert_equal [ 200, true, deck.id ], [ session.response.status, *session.response.parsed_body.dig("data", "players", 0).values_at("ready", "deck_id") ]
      assert_equal [ true, true, nil ], events(syrus).last.data[:players].first.values_at(:ready, :deck_chosen, :deck_id)
    end

    it "o último a ficar pronto começa o duelo e os dois vão para a partida" do
      room = room_for(jaden)
      room.players.create!(user: syrus, seat: 1, deck: Decks::StarterDeck.give_to(syrus) && syrus.decks.sole, ready: true)
      Decks::StarterDeck.give_to(jaden)
      session = session_for(jaden)
      session.post ready_api_room_path(room.code), params: { deck_id: jaden.decks.sole.id, ready: true }, as: :json

      match = Match.sole
      assert_equal [ "dueling", match.id ], session.response.parsed_body["data"].values_at("status", "match_id")
      [ jaden, syrus ].each do |user|
        assert_includes events(user).map { |event| [ event.name, event.data ] }, [ "match.started", { code: room.code, match_id: match.id } ]
      end
    end

    it "recusa deck incompleto e deck de outro jogador, e deixa de ficar pronto" do
      room = room_for(jaden)
      session = session_for(jaden)
      session.post ready_api_room_path(room.code), params: { deck_id: jaden.decks.create!(name: "Vazio").id, ready: true }, as: :json
      assert_equal [ 422, "Este deck não vale nesta sala." ], [ session.response.status, session.response.parsed_body.dig("error", "message") ]
      assert_not_empty session.response.parsed_body.dig("error", "fields", "deck")

      session.post ready_api_room_path(room.code), params: { deck_id: syrus.decks.create!(name: "Roid").id, ready: true }, as: :json
      assert_equal 404, session.response.status

      room.players.first.update!(ready: true)
      session.post ready_api_room_path(room.code), params: { ready: false }, as: :json
      assert_equal false, room.players.first.reload.ready
    end
  end

  it "o dono tira alguém da sala; os outros não podem" do
    room = room_for(jaden)
    room.players.create!(user: syrus, seat: 1)
    guest = session_for(syrus)
    guest.post kick_api_room_path(room.code), params: { user_id: jaden.id }, as: :json
    assert_equal 403, guest.response.status

    session_for(jaden).post kick_api_room_path(room.code), params: { user_id: syrus.id }, as: :json
    assert_equal [ jaden.id ], room.players.reload.map(&:user_id)
    assert_equal [ "room.kicked", { code: room.code } ], [ events(syrus).last.name, events(syrus).last.data ]
  end

  it "sala em duelo não aceita entrada, e quem duela não troca de sala" do
    room = room_for(jaden, status: "dueling")
    guest = session_for(syrus)
    guest.post join_api_room_path(room.code), as: :json
    assert_equal "Esta sala já está em duelo.", guest.response.parsed_body.dig("error", "message")

    owner = session_for(jaden)
    owner.post api_rooms_path, as: :json
    assert_equal [ 422, "Você está num duelo." ], [ owner.response.status, owner.response.parsed_body.dig("error", "message") ]
    # Sair no meio do duelo, só desistindo antes (o botão "Desistir" fica na mesa).
    owner.post leave_api_room_path(room.code), as: :json
    assert_equal [ 422, "Desista do duelo antes de sair da sala." ], [ owner.response.status, owner.response.parsed_body.dig("error", "message") ]
    assert room.reload.players.exists?(user: jaden)
  end

  it "duelo com o prazo vencido não prende ninguém: acaba por tempo e o jogador cria outra sala" do
    load_starter_deck_cards
    room = room_for(jaden)
    room.players.create!(user: syrus, seat: 1)
    [ jaden, syrus ].each { |user| Decks::StarterDeck.give_to(user) }
    room.players.each { |player| player.update!(deck: player.user.decks.sole, ready: true) }
    match = Matches::Start.new(room).call
    owner = session_for(jaden)

    owner.post api_rooms_path, as: :json
    assert_equal 422, owner.response.status

    travel_to(match.reload.deadline_at + 1.second) do
      owner.post api_rooms_path, as: :json
      assert_equal 201, owner.response.status
    end
    assert_equal [ "finished", "timeout", 1 - match.prompt_team ], match.reload.values_at(:status, :finish_reason, :winner_team)
  end

  it "mostra a sala pelo código, em maiúsculas ou minúsculas" do
    room = room_for(jaden)
    session = session_for(syrus)
    session.get api_room_path(room.code.downcase)

    assert_equal [ room.code, [ "Jaden" ] ], [ session.response.parsed_body.dig("data", "code"),
                                              session.response.parsed_body.dig("data", "players").pluck("nickname") ]
  end

  it "dois pegando o último lugar ao mesmo tempo: o segundo ouve que a sala encheu" do
    room = room_for(jaden)
    # O lugar 0 parece livre, mas o dono já está nele: o índice único recusa.
    Room.any_instance.stubs(:free_seat).returns(0)
    guest = session_for(syrus)
    guest.post join_api_room_path(room.code), as: :json

    assert_equal [ 422, "A sala está cheia.", 1 ], [ guest.response.status, guest.response.parsed_body.dig("error", "message"), room.players.count ]
  end

  it "código desconhecido e sala de que não faz parte dão 404" do
    session = session_for(jaden)
    session.get api_room_path("ZZZZZZ")
    assert_equal 404, session.response.status

    session.post leave_api_room_path(room_for(syrus).code), as: :json
    assert_equal 404, session.response.status
  end

  it "sem o Ably no ar, a sala muda do mesmo jeito" do
    room = room_for(jaden)
    Realtime::MemoryPublisher.any_instance.stubs(:publish).raises(Realtime::AblyPublisher::Error, "sem conexão")
    guest = session_for(syrus)
    guest.post join_api_room_path(room.code), as: :json

    assert_equal [ 200, 2 ], [ guest.response.status, room.players.count ]
  end
end
