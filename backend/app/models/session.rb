# Um login do usuário: o cookie guarda o id desta linha, assinado (ADR 0008).
class Session < ApplicationRecord
  belongs_to :user
end
