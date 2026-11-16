# As estatísticas do duelo (GXP-87; Duel::Stats): o que cada time fez, contado das mensagens
# da engine a cada jogada, para os bônus de DP e os desafios.
class AddStatsToMatches < ActiveRecord::Migration[8.1]
  def change
    add_column :matches, :stats, :jsonb
  end
end
