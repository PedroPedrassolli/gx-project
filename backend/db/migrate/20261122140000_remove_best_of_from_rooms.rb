# Sem melhor de 3 (GXP-125), a sala não usa mais best_of. O modelo já ignorava a coluna desde
# o deploy anterior, então o código no ar não quebra quando ela some (GXP-129).
class RemoveBestOfFromRooms < ActiveRecord::Migration[8.1]
  def change
    remove_column :rooms, :best_of, :integer, default: 1, null: false
  end
end
