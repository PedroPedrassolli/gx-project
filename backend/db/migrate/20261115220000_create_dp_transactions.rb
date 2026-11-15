# Economia (GXP-85; ADR 0005): o razão de DP, em que cada mudança de saldo é uma linha nova com
# o saldo depois dela e uma chave que não se repete por jogador; o nível e o DP ganho do
# jogador; os bônus de cada duelo no jogador da partida; e o motivo da vitória que a engine deu
# (PV, deck vazio, Exodia...).
class CreateDpTransactions < ActiveRecord::Migration[8.1]
  def change
    create_table :dp_transactions do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.string :reason, null: false
      t.integer :amount, null: false
      t.integer :balance_after, null: false
      t.references :ref, polymorphic: true
      t.string :key, null: false
      t.text :note
      t.datetime :created_at, null: false
    end
    add_index :dp_transactions, %i[user_id key], unique: true
    add_index :dp_transactions, %i[user_id id]

    add_column :users, :level, :integer, null: false, default: 1
    add_column :users, :dp_earned, :integer, null: false, default: 0
    add_column :match_players, :rewards, :jsonb
    add_column :matches, :win_reason, :integer
  end
end
