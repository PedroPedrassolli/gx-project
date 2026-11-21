# O personagem que o computador joga nesse lugar da partida (escopo 3.10; ADR 0013). Nulo é
# jogador de verdade.
class AddCharacterToMatchPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :match_players, :character, :string
  end
end
