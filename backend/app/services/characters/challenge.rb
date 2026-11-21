module Characters
  # Começa o duelo de um jogador contra um personagem (escopo 3.10; ADR 0013). O lugar do
  # computador recebe o deck do personagem, embaralhado como o de qualquer um; quem começa é
  # sorteado. Sem relógio (dá para pensar com calma) e sem banlist dos dois lados.
  class Challenge
    # O duelo não começa; a mensagem vai pronta para a tela.
    class Refused < StandardError; end

    def initialize(user, character, deck)
      @user = user
      @character = character
      @deck = deck
    end

    def call
      Match.transaction do
        # Dois toques seguidos no botão esperam um pelo outro: só um duelo começa.
        @user.lock!
        check!
        match = Match.create!(mode: "1x1", banlist: false, destiny_draw: true, decision_seconds: nil, duel_minutes: nil, turn_time_left: 0,
                              seed: Array.new(4) { SecureRandom.random_number(2**63) }, started_at: Time.current)
        player, bot = [ 0, 1 ].shuffle(random: SecureRandom)
        match.players.create!(user: @user, team: player, seat: player, deck: Decks::Snapshot.of(@deck))
        match.players.create!(character: @character.id, team: bot, seat: bot, deck: bot_deck)
        Matches::Game.new(match).start!
        match
      end
    end

    private

    def check!
      raise Refused, "Vença #{Roster.before(@character).name} para liberar #{@character.name}." unless Progress.new(@user).unlocked?(@character)
      raise Refused, "Termine o duelo que está em andamento antes de começar outro." if Match.current_for(@user)
      raise Refused, "Saia da sala para duelar contra um personagem." if @user.room_player

      errors = Decks::Validator.for(@deck, banlist: false).errors
      raise Refused, "Esse deck não vale: #{errors.first}" if errors.any?
    end

    # O deck do personagem com os códigos da engine (os nomes do YAML são os do catálogo).
    def bot_deck
      codes = Card.where(name: @character.deck.card_names).pluck(:name, :engine_code).to_h
      expand = ->(cards) { cards.flat_map { |name, copies| [ codes.fetch(name) ] * copies } }
      { main: expand.call(@character.deck.main).shuffle(random: SecureRandom), extra: expand.call(@character.deck.extra), destiny: [] }
    end
  end
end
