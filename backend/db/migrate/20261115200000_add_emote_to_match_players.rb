# Emotes na mesa (GXP-83, ADR 0011 item 19): a última frase de cada jogador e quando saiu.
# Quem está sem tempo real vê na consulta seguinte.
class AddEmoteToMatchPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :match_players, :emote, :string
    add_column :match_players, :emote_at, :datetime
  end
end
