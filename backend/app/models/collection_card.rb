# Uma carta da coleção do jogador: quantas cópias ele tem (escopo 3.2).
class CollectionCard < ApplicationRecord
  belongs_to :user
  belongs_to :card

  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
end
