# Coleção do jogador (escopo 3.2 e 5.7): quantas cópias de cada carta ele tem e quando
# ganhou a primeira (para ordenar o baú por data de obtenção).
class CreateCollectionCards < ActiveRecord::Migration[8.1]
  def change
    create_table :collection_cards do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.references :card, null: false, foreign_key: true
      t.integer :quantity, null: false
      t.datetime :obtained_at, null: false
      t.timestamps
    end
    add_index :collection_cards, %i[user_id card_id], unique: true
  end
end
