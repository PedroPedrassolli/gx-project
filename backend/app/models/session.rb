# Um login do usuário: o cookie guarda o id desta linha, assinado (ADR 0008).
class Session < ApplicationRecord
  # Cada login vale 90 dias. Depois, é preciso entrar de novo: um cookie roubado não vale
  # para sempre.
  DURATION = 90.days

  belongs_to :user

  scope :active, -> { where(created_at: DURATION.ago..) }
  scope :expired, -> { where(created_at: ...DURATION.ago) }
end
