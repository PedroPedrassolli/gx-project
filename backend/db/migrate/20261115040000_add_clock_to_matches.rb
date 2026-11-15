# O tempo do duelo (escopo 3.7, GXP-53): quando a pergunta da vez abriu, até quando ela pode
# ser respondida, quanto sobra do banco de tempo do turno de quem joga e por que a partida
# acabou (duelo, desistência, tempo ou limite do duelo).
class AddClockToMatches < ActiveRecord::Migration[8.1]
  def change
    change_table :matches, bulk: true do |t|
      t.datetime :prompt_at
      t.datetime :deadline_at
      t.integer :turn_time_left, null: false, default: 300
      t.string :finish_reason
    end
  end
end
