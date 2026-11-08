module Accounts
  # Tudo o que guardamos de um jogador (LGPD, direito de acesso e portabilidade). Quando
  # surgir dado novo da conta (DP, partidas, amigos), ele entra aqui também.
  class DataExport
    def initialize(user)
      @user = user
    end

    def as_json(*)
      {
        exported_at: Time.current,
        account: @user.slice(:email, :email_verified_at, :nickname, :age_group, :role, :terms_accepted_at, :created_at),
        sessions: @user.sessions.order(:created_at).map { |session| { created_at: session.created_at } },
        collection: @user.collection_cards.includes(:card).order(:obtained_at, :id).map do |row|
          { card: row.card.name, quantity: row.quantity, obtained_at: row.obtained_at }
        end,
        decks: @user.decks.includes(deck_cards: :card).order(:name).map { |deck| deck_json(deck) }
      }.as_json
    end

    private

    def deck_json(deck)
      cards = deck.deck_cards.sort_by(&:id).map do |row|
        { card: row.card.name, section: row.section, quantity: row.quantity, destiny: row.destiny }
      end
      { name: deck.name, created_at: deck.created_at, updated_at: deck.updated_at, cards: }
    end
  end
end
