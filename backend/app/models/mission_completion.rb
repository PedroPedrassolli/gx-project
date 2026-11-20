# Uma missão concluída por um jogador (as missões estão em db/seeds/missoes.yml). period é
# "once" na missão que só vale uma vez, a semana na semanal e a partida na que sempre repete.
class MissionCompletion < ApplicationRecord
  belongs_to :user
  belongs_to :card, optional: true
  belongs_to :match, optional: true
end
