# Um duelista da partida, com o deck do jeito que entrou no duelo (já embaralhado).
class MatchPlayer < ApplicationRecord
  # As frases da mesa (escopo 3.7: sem chat livre, só emotes; GXP-83). O texto de cada uma fica
  # no front (duel/emotes.ts).
  EMOTES = %w[hello luck nice think oops gg].freeze
  # Uma frase a cada tanto, e por quanto tempo a última aparece na mesa de quem consulta.
  EMOTE_EVERY = 3.seconds
  EMOTE_SHOWN = 8.seconds

  belongs_to :match
  # Sem dono quando a conta foi apagada.
  belongs_to :user, optional: true
end
