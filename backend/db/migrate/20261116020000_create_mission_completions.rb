# Missões e códigos secretos (GXP-89; db/seeds/missoes.yml e Economy::Missions): as missões
# que cada jogador concluiu (a que repete, uma vez por período), com a carta que ganhou; os
# códigos que ele já digitou na loja; e a vitória que conta para missão, marcada no jogador
# da partida.
class CreateMissionCompletions < ActiveRecord::Migration[8.1]
  def change
    create_table :mission_completions do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.string :mission, null: false
      t.string :period, null: false
      t.references :card, foreign_key: true
      t.references :match, foreign_key: { on_delete: :nullify }
      t.datetime :created_at, null: false
    end
    add_index :mission_completions, %i[user_id mission period], unique: true

    create_table :code_unlocks do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.string :code, null: false
      t.datetime :created_at, null: false
    end
    add_index :code_unlocks, %i[user_id code], unique: true

    add_column :match_players, :mission_win, :boolean, null: false, default: false
  end
end
