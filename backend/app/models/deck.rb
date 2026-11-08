# Deck do jogador (escopo 3.3). As regras ficam no Decks::Validator.
class Deck < ApplicationRecord
  # Teto de decks por conta, para o banco grátis não crescer sem limite (ADR 0009).
  LIMIT_PER_USER = 50

  belongs_to :user
  has_many :deck_cards, dependent: :delete_all

  validates :name, presence: true, length: { maximum: 40 }
end
