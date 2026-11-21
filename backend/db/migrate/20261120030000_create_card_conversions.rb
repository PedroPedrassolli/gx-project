# O conversor da loja (GXP-90; Shop::Converter): cada conversão de um jogador, com as cartas
# que ele gastou, a semente do sorteio e a carta que saiu. A chave da conversão é única por
# jogador: o mesmo pedido mandado duas vezes não gasta cartas de novo.
class CreateCardConversions < ActiveRecord::Migration[8.1]
  def change
    create_table :card_conversions do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.string :key, null: false
      t.integer :amount, null: false
      t.jsonb :spent, null: false
      t.bigint :seed, null: false
      t.references :card, null: false, foreign_key: true
      t.boolean :new_card, null: false
      t.datetime :created_at, null: false
    end
    add_index :card_conversions, %i[user_id key], unique: true
  end
end
