# Uma carta numa seção do deck. Responde a card_id, section, quantity e destiny, como o
# Decks::Entry que o Decks::Validator lê.
class DeckCard < ApplicationRecord
  SECTIONS = %w[main extra side].freeze

  belongs_to :deck
  belongs_to :card

  validates :section, inclusion: { in: SECTIONS }
  validates :quantity, numericality: { only_integer: true, in: 1..3 }
end
