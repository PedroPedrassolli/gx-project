# Os desafios que cada jogador já concluiu (GXP-88; Economy::Challenges), com a partida em que
# concluiu. Cada desafio conta uma vez por jogador.
class CreateUserChallenges < ActiveRecord::Migration[8.1]
  def change
    create_table :user_challenges do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.integer :number, null: false
      t.references :match, foreign_key: { on_delete: :nullify }
      t.datetime :created_at, null: false
    end
    add_index :user_challenges, %i[user_id number], unique: true
  end
end
