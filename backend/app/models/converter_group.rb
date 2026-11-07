# Grupo do conversor: quem põe `amount` cartas repetidas ganha uma carta sorteada do grupo.
class ConverterGroup < ApplicationRecord
  has_many :group_cards, class_name: "ConverterGroupCard", dependent: :destroy
  has_many :cards, through: :group_cards
end
