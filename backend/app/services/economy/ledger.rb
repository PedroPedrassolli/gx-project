module Economy
  # O razão de DP (ADR 0005 itens 1 a 3). O saldo é o da última linha do jogador. Cada
  # lançamento trava o jogador (duas compras ao mesmo tempo esperam uma pela outra), recusa o
  # débito que deixaria o saldo negativo e, com uma chave repetida, devolve o lançamento que já
  # existe, sem pagar nem cobrar de novo. O crédito também soma no DP ganho, que dá o nível.
  module Ledger
    class InsufficientBalance < StandardError; end

    module_function

    def balance(user) = user.dp_transactions.order(id: :desc).pick(:balance_after) || 0

    def post!(user, amount, reason:, key:, ref: nil, note: nil)
      user.with_lock do
        existing = user.dp_transactions.find_by(key:)
        next existing if existing

        balance_after = balance(user) + amount
        raise InsufficientBalance, "DP insuficiente." if balance_after.negative?

        user.increment!(:dp_earned, amount) if amount.positive?
        user.dp_transactions.create!(amount:, balance_after:, reason:, key:, ref:, note:)
      end
    end
  end
end
