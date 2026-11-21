module Accounts
  # Tudo o que guardamos de um jogador (LGPD, direito de acesso e portabilidade). Quando
  # surgir dado novo da conta (amigos, fila), ele entra aqui também.
  class DataExport
    def initialize(user)
      @user = user
    end

    def as_json(*)
      {
        exported_at: Time.current,
        account: @user.slice(:email, :email_verified_at, :nickname, :age_group, :role, :terms_accepted_at, :created_at,
                             :level, :dp_earned),
        sessions: @user.sessions.order(:created_at).map { |session| { created_at: session.created_at } },
        collection: @user.collection_cards.includes(:card).order(:obtained_at, :id).map do |row|
          { card: row.card.name, quantity: row.quantity, obtained_at: row.obtained_at }
        end,
        decks: @user.decks.includes(deck_cards: :card).order(:name).map { |deck| deck_json(deck) },
        # O razão do DP (GXP-85): cada crédito e débito, com o saldo depois dele.
        dp: @user.dp_transactions.order(:id).map { |row| row.slice(:amount, :balance_after, :reason, :note, :created_at) },
        pack_openings:,
        matches:,
        challenges: @user.user_challenges.order(:number).map do |row|
          { number: row.number, label: Economy::Challenges.label(row.number), completed_at: row.created_at }
        end,
        missions: @user.mission_completions.includes(:card).order(:created_at, :id).map do |row|
          { mission: Economy::Missions.name_of(row.mission), period: row.period, card: row.card&.name, completed_at: row.created_at }
        end,
        secret_codes: @user.code_unlocks.order(:created_at, :id).map { |row| { code: row.code, unlocked_at: row.created_at } },
        conversions:,
        # As vitórias contra os personagens (ADR 0013).
        characters: @user.character_wins.order(:created_at, :id).map do |row|
          { character: Characters::Roster.find(row.character)&.name || row.character, wins: row.wins, first_win_at: row.created_at }
        end
      }.as_json
    end

    private

    def deck_json(deck)
      cards = deck.deck_cards.sort_by(&:id).map do |row|
        { card: row.card.name, section: row.section, quantity: row.quantity, destiny: row.destiny }
      end
      { name: deck.name, created_at: deck.created_at, updated_at: deck.updated_at, cards: }
    end

    # Os pacotes abertos na loja, com o nome de cada carta que saiu.
    def pack_openings
      openings = @user.pack_openings.includes(:pack).order(:id).to_a
      names = Card.where(id: openings.flat_map { |opening| opening.cards.pluck("id") }).pluck(:id, :name).to_h
      openings.map do |opening|
        { pack: opening.pack.name, opened_at: opening.created_at, cards: opening.cards.map { |card| names[card["id"]] } }
      end
    end

    # As conversões de cartas repetidas (GXP-90): o que foi gasto e a carta que saiu.
    def conversions
      rows = @user.card_conversions.includes(:card).order(:id).to_a
      names = Card.where(id: rows.flat_map { |row| row.spent.keys }).pluck(:id, :name).to_h
      rows.map do |row|
        { converted_at: row.created_at, spent: row.spent.to_h { |id, quantity| [ names[id.to_i], quantity ] }, card: row.card.name }
      end
    end

    # As partidas do jogador: quando foram, como acabaram e quanto DP renderam.
    def matches
      MatchPlayer.where(user_id: @user.id).includes(:match).order(:id).map do |player|
        match = player.match
        result = if match.winner_team.nil? then "empate" elsif match.winner_team == player.team then "vitória" else "derrota" end
        { started_at: match.created_at, finished_at: match.finished_at, result: (result if match.finished_at),
          dp: player.rewards&.dig("total") }
      end
    end
  end
end
