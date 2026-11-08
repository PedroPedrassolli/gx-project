# Uma linha por login (ADR 0008). Sem IP nem navegador: não precisamos desses dados.
class CreateSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end
  end
end
