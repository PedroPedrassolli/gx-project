module Matches
  # Começa o duelo quando a sala está cheia e todos estão prontos (GXP-48; ADR 0011): põe
  # quem começa no time 0 (a engine começa por ele), embaralha os decks e guarda tudo na
  # partida.
  class Start
    # first_seat: o lugar que começa, escolhido no pedra, papel e tesoura (Rooms::Opening).
    # Sem ele (testes e o robô de duelos), sorteio.
    def initialize(room, first_seat: nil)
      @room = room
      @first_seat = first_seat
    end

    # A partida nova, ou nil se ainda falta alguém, se um deck deixou de valer ou se outro
    # pedido já começou o duelo.
    def call
      started = Room.transaction do
        @room.lock!
        players = @room.players.to_a
        next unless ready?(players)

        decks = Deck.includes(:user, :deck_cards).where(id: players.map(&:deck_id)).index_by(&:id)
        next unless decks_still_valid?(players, decks)

        create_match(players, decks)
      end
      # Duelo novo é a hora de tirar do banco os replays vencidos.
      Cleanup.call if started
      started
    end

    private

    def ready?(players) = @room.waiting? && players.size == @room.seats && players.all? { |player| player.ready && player.deck_id }

    # O deck pode ter mudado depois do "pronto": vale o que ele é agora. Quem ficou com deck
    # que não vale deixa de estar pronto, e o duelo espera (escopo 3.3).
    def decks_still_valid?(players, decks)
      invalid = players.reject { |player| Decks::Validator.for(decks.fetch(player.deck_id), banlist: @room.banlist).valid? }
      invalid.each { |player| player.update!(ready: false) }
      invalid.empty?
    end

    def create_match(players, decks)
      match = Match.create!(room: @room, mode: @room.mode, banlist: @room.banlist, destiny_draw: @room.destiny_draw,
                            decision_seconds: @room.decision_seconds, duel_minutes: @room.duel_minutes,
                            turn_time_left: Clock.turn_bank(@room.decision_seconds),
                            seed: Array.new(4) { SecureRandom.random_number(2**63) }, started_at: Time.current)
      in_turn_order(players).each_with_index do |player, team|
        match.players.create!(user_id: player.user_id, seat: player.seat, team:, deck: Decks::Snapshot.of(decks.fetch(player.deck_id)))
      end
      @room.update!(status: "dueling", hands: {}, last_hands: nil, chooser_seat: nil)
      Game.new(match).start!
      match
    end

    # Quem começa vai para o time 0.
    def in_turn_order(players)
      return players.shuffle(random: SecureRandom) unless @first_seat

      players.sort_by { |player| player.seat == @first_seat ? 0 : 1 }
    end
  end
end
