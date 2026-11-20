# Uma carta da coleção do jogador: quantas cópias ele tem (escopo 3.2).
class CollectionCard < ApplicationRecord
  belongs_to :user
  belongs_to :card

  validates :quantity, numericality: { only_integer: true, greater_than: 0 }

  # Põe cartas na coleção: { id da carta => quantas }. Uma consulta só, somando às cópias
  # que o jogador já tem.
  def self.add!(user, quantities)
    now = Time.current
    rows = quantities.map { |card_id, quantity| { user_id: user.id, card_id:, quantity:, obtained_at: now } }
    upsert_all(rows, unique_by: %i[user_id card_id], record_timestamps: true,
                     on_duplicate: Arel.sql("quantity = collection_cards.quantity + EXCLUDED.quantity, updated_at = EXCLUDED.updated_at"))
  end
end
