# Salas de duelo (escopo 3.6 e 5.7; ADR 0010). A sala guarda as opções e quem está em cada
# lugar; a partida (GXP-48) nasce quando todos ficam prontos.
class CreateRooms < ActiveRecord::Migration[8.1]
  def change
    create_table :rooms do |t|
      t.string :code, null: false, limit: 6
      t.references :owner, null: false, foreign_key: { to_table: :users }
      t.boolean :public, null: false, default: true
      t.string :mode, null: false, default: "1x1"
      # Partida simples (1) ou melhor de 3 (F5).
      t.integer :best_of, null: false, default: 1
      # true: a banlist do jogo; false: sala sem banlist.
      t.boolean :banlist, null: false, default: true
      t.boolean :destiny_draw, null: false, default: true
      t.string :status, null: false, default: "waiting"
      t.timestamps
    end
    add_index :rooms, :code, unique: true
    add_index :rooms, %i[status public updated_at]

    # Um jogador fica numa sala só por vez (índice único em user_id).
    create_table :room_players do |t|
      t.references :room, null: false, foreign_key: true, index: false
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.references :deck, foreign_key: { on_delete: :nullify }
      t.integer :seat, null: false
      t.boolean :ready, null: false, default: false
      t.timestamps
    end
    add_index :room_players, %i[room_id seat], unique: true
  end
end
