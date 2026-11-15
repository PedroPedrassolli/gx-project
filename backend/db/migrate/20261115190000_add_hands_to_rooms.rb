# Quem começa sai no pedra, papel e tesoura (GXP-81, ADR 0010 item 9): a mão de cada lugar
# na rodada, a rodada anterior (que todos veem) e o lugar de quem ganhou e escolhe quem começa.
class AddHandsToRooms < ActiveRecord::Migration[8.1]
  def change
    add_column :rooms, :hands, :jsonb, null: false, default: {}
    add_column :rooms, :last_hands, :jsonb
    add_column :rooms, :chooser_seat, :integer
  end
end
