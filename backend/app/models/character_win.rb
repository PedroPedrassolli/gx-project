# As vitórias de um jogador contra um personagem (escopo 3.10; ADR 0013). character é o id da
# lista (Characters::Roster). A linha nasce na primeira vitória.
class CharacterWin < ApplicationRecord
  belongs_to :user
end
