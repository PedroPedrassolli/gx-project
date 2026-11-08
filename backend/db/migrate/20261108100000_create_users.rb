# Contas dos jogadores (escopo 3.1 e 5.7; ADR 0008). Da data de nascimento só fica a faixa.
class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :nickname, null: false
      t.string :age_group, null: false
      t.string :role, null: false, default: "player"
      t.timestamps
    end
    add_index :users, :email, unique: true
    # Apelido único sem diferenciar maiúsculas: "Jaden" e "jaden" são o mesmo.
    add_index :users, "lower(nickname)", unique: true, name: "index_users_on_lower_nickname"
  end
end
