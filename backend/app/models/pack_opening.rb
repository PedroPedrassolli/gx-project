# Um pacote aberto na loja (GXP-86): as cartas que saíram (id, raridade e se era nova para o
# jogador) e a semente do sorteio. Depois de gravado, não muda.
class PackOpening < ApplicationRecord
  belongs_to :user
  belongs_to :pack

  def readonly? = persisted?
end
