# Uma carta numa seção do deck. Responde a card_id, section, quantity e destiny, como o
# Decks::Entry que o Decks::Validator lê.
class DeckCard < ApplicationRecord
  # Sem Side Deck desde 22/11/2026: não há melhor de 3 (GXP-125).
  SECTIONS = %w[main extra].freeze

  belongs_to :deck
  belongs_to :card

  validates :section, inclusion: { in: SECTIONS }
  validates :quantity, numericality: { only_integer: true, in: 1..3 }
end
