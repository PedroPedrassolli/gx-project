# As vitórias de cada jogador contra cada personagem (escopo 3.10; ADR 0013): a primeira libera o
# próximo da lista e dá a carta-símbolo, uma vez só (o índice único garante).
class CreateCharacterWins < ActiveRecord::Migration[8.1]
  def change
    create_table :character_wins do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.string :character, null: false
      t.integer :wins, null: false, default: 0
      t.timestamps
    end
    add_index :character_wins, %i[user_id character], unique: true
  end
end
