# Deck do jogador (escopo 3.3). As regras ficam no Decks::Validator.
class Deck < ApplicationRecord
  belongs_to :user
  has_many :deck_cards, dependent: :delete_all

  validates :name, presence: true, length: { maximum: 40 }
end
