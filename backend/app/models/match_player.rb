# Um duelista da partida, com o deck do jeito que entrou no duelo (já embaralhado).
class MatchPlayer < ApplicationRecord
  belongs_to :match
  # Sem dono quando a conta foi apagada.
  belongs_to :user, optional: true
end
