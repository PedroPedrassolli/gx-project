# O dono da sala escolhe o tempo de resposta e o do duelo (GXP-80, ADR 0011 item 18). A
# partida copia da sala no começo. Nulo é sem limite; o padrão é o tempo fixo de antes.
class AddTimesToRoomsAndMatches < ActiveRecord::Migration[8.1]
  def change
    add_column :rooms, :decision_seconds, :integer, default: 90
    add_column :rooms, :duel_minutes, :integer, default: 60
    add_column :matches, :decision_seconds, :integer, default: 90
    add_column :matches, :duel_minutes, :integer, default: 60
  end
end
