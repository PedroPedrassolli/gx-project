# Decks do jogador (escopo 3.3 e 5.7): cada linha de deck_cards é uma carta numa seção
# (main, extra ou side), com quantas cópias e se é Destiny.
class CreateDecks < ActiveRecord::Migration[8.1]
  def change
    create_table :decks do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.timestamps
    end

    create_table :deck_cards do |t|
      t.references :deck, null: false, foreign_key: true, index: false
      t.references :card, null: false, foreign_key: true
      t.string :section, null: false
      t.integer :quantity, null: false
      t.boolean :destiny, null: false, default: false
      t.timestamps
    end
    add_index :deck_cards, %i[deck_id card_id section], unique: true
  end
end
