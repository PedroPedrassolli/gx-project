# Dados do pedido em andamento: a sessão do login e, por ela, o usuário (ADR 0008).
class Current < ActiveSupport::CurrentAttributes
  attribute :session
  delegate :user, to: :session, allow_nil: true
end
