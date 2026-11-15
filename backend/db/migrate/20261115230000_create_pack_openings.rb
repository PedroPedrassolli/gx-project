# A loja (GXP-86; ADR 0005 item 7): cada pacote aberto fica guardado, com a semente do sorteio
# (a compra de 10 usa uma semente só, e a posição diz a ordem) e as cartas que saíram. A chave
# da compra faz o mesmo pedido repetido devolver a mesma compra.
class CreatePackOpenings < ActiveRecord::Migration[8.1]
  def change
    create_table :pack_openings do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.references :pack, null: false, foreign_key: true
      t.string :purchase_key, null: false
      t.integer :position, null: false
      t.bigint :seed, null: false
      t.jsonb :cards, null: false
      t.datetime :created_at, null: false
    end
    add_index :pack_openings, %i[user_id purchase_key position], unique: true
  end
end
