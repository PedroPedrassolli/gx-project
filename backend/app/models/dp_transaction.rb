# Uma linha do razão de DP (ADR 0005): crédito (positivo) ou débito (negativo), o saldo depois
# dela, o motivo e a chave que impede pagar ou cobrar duas vezes. Depois de gravada, não muda.
class DpTransaction < ApplicationRecord
  belongs_to :user
  belongs_to :ref, polymorphic: true, optional: true

  def readonly? = persisted?
end
