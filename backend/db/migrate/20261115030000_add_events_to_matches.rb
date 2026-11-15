# O log e a pilha da corrente da mesa (GXP-65): os últimos eventos do duelo, com os códigos
# (a Duel::View tira o que cada lado não vê), quantos já houve (para numerar) e os elos da
# corrente aberta.
class AddEventsToMatches < ActiveRecord::Migration[8.1]
  def change
    change_table :matches, bulk: true do |t|
      t.jsonb :events, null: false, default: []
      t.integer :events_count, null: false, default: 0
      t.jsonb :chain, null: false, default: []
    end
  end
end
