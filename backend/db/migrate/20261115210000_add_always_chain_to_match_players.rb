# "Sempre perguntar" na corrente (GXP-84, ADR 0011 item 20): a mesa pergunta mesmo quando o
# jogador não tem o que encadear. O navegador guarda a escolha e manda em cada duelo.
class AddAlwaysChainToMatchPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :match_players, :always_chain, :boolean, null: false, default: false
  end
end
