# Uma conversão de cartas repetidas na loja (GXP-90; Shop::Converter). spent guarda o que o
# jogador gastou: { "id da carta" => quantas }.
class CardConversion < ApplicationRecord
  belongs_to :user
  belongs_to :card
end
