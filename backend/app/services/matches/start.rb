module Matches
  # Começa o duelo quando a sala está cheia e todos estão prontos (GXP-48; ADR 0011): sorteia
  # quem começa, embaralha os decks e guarda tudo na partida. A engine só roda quando o duelo
  # é aberto (GXP-49).
  class Start
    def initialize(room)
      @room = room
    end

    # A partida nova, ou nil se ainda falta alguém (ou outro pedido já começou o duelo).
    def call
      Room.transaction do
        @room.lock!
        players = @room.players.to_a
        next unless @room.waiting? && players.size == @room.seats && players.all? { |player| player.ready && player.deck_id }

        decks = Deck.includes(deck_cards: :card).where(id: players.map(&:deck_id)).index_by(&:id)
        match = Match.create!(room: @room, mode: @room.mode, banlist: @room.banlist, destiny_draw: @room.destiny_draw,
                              seed: Array.new(4) { SecureRandom.random_number(2**63) }, started_at: Time.current)
        # Quem começa sai no sorteio: a pedra, papel e tesoura do escopo (3.7) vem depois.
        players.shuffle(random: SecureRandom).each_with_index do |player, team|
          match.players.create!(user_id: player.user_id, seat: player.seat, team:, deck: snapshot(decks.fetch(player.deck_id)))
        end
        @room.update!(status: "dueling")
        Game.new(match).start!
        match
      end
    end

    private

    # O deck do jeito que a engine recebe: os códigos do Main embaralhados, o Extra e as
    # cartas marcadas como Destiny.
    def snapshot(deck)
      rows = deck.deck_cards.to_a
      codes = ->(section) { rows.select { |row| row.section == section }.flat_map { |row| [ row.card.engine_code ] * row.quantity } }
      { main: codes.call("main").shuffle(random: SecureRandom), extra: codes.call("extra"),
        destiny: rows.select { |row| row.section == "main" && row.destiny }.map { |row| row.card.engine_code } }
    end
  end
end
