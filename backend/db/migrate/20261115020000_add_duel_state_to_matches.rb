# O que a tela do duelo precisa e a engine não guarda (ADR 0011): o turno, de quem é a vez,
# a fase e a pergunta que espera resposta (com o time que responde).
class AddDuelStateToMatches < ActiveRecord::Migration[8.1]
  def change
    change_table :matches, bulk: true do |t|
      t.integer :turn, null: false, default: 0
      t.integer :turn_team, null: false, default: 0
      t.integer :phase, null: false, default: 0
      t.jsonb :prompt
      t.integer :prompt_team
    end
  end
end
