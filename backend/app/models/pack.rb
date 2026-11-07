# Pacote da loja, com o preço em DP e a regra de disponibilidade (escopo, 3.4).
class Pack < ApplicationRecord
  has_many :pack_cards, dependent: :destroy
  has_many :cards, through: :pack_cards
end
