require "test_helper"

class Economy::LedgerTest < ActiveSupport::TestCase
  let(:user) { User.create!(email: "jaden@example.com", password: "duelista123", nickname: "Jaden", age_group: "18+") }

  it "o saldo é o da última linha; o crédito soma no DP ganho e o débito não" do
    assert_equal 0, Economy::Ledger.balance(user)
    Economy::Ledger.post!(user, 300, reason: "duel", key: "partida:1")
    Economy::Ledger.post!(user, -100, reason: "pack", key: "compra:a")

    assert_equal [ 200, 300 ], [ Economy::Ledger.balance(user), user.reload.dp_earned ]
    assert_equal [ 300, 200 ], user.dp_transactions.order(:id).pluck(:balance_after)
  end

  it "o DP de subir de nível entra no saldo, mas não conta para o próximo nível" do
    Economy::Ledger.post!(user, 300, reason: "duel", key: "partida:1")
    Economy::Ledger.post!(user, 100, reason: "level_up", key: "nivel:2")

    assert_equal [ 400, 300 ], [ Economy::Ledger.balance(user), user.reload.dp_earned ]
  end

  it "a chave repetida devolve o lançamento que já existe, sem pagar de novo" do
    first = Economy::Ledger.post!(user, 300, reason: "duel", key: "partida:1")
    again = Economy::Ledger.post!(user, 300, reason: "duel", key: "partida:1")

    assert_equal [ first.id, 300, 1 ], [ again.id, Economy::Ledger.balance(user), user.dp_transactions.count ]
  end

  it "débito maior que o saldo é recusado e nada muda" do
    Economy::Ledger.post!(user, 50, reason: "duel", key: "partida:1")

    assert_raises(Economy::Ledger::InsufficientBalance) { Economy::Ledger.post!(user, -100, reason: "pack", key: "compra:a") }
    assert_equal [ 50, 1 ], [ Economy::Ledger.balance(user), user.dp_transactions.count ]
  end

  it "a linha gravada não muda" do
    line = Economy::Ledger.post!(user, 50, reason: "duel", key: "partida:1")

    assert_raises(ActiveRecord::ReadOnlyRecord) { line.update!(amount: 5_000) }
  end
end

# Duas compras ao mesmo tempo, cada uma na sua conexão: a trava faz uma esperar a outra, e a
# segunda vê o saldo já gasto (ADR 0005, consequências). Fora da transação dos testes.
class Economy::LedgerConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  it "duas compras ao mesmo tempo não deixam o saldo negativo" do
    user = User.create!(email: "syrus@example.com", password: "duelista123", nickname: "Syrus", age_group: "18+")
    Economy::Ledger.post!(user, 100, reason: "duel", key: "partida:1")
    results = Array.new(2) do |index|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          Economy::Ledger.post!(User.find(user.id), -100, reason: "pack", key: "compra:#{index}")
          :ok
        rescue Economy::Ledger::InsufficientBalance
          :recusada
        end
      end
    end.map(&:value)

    assert_equal [ :ok, :recusada ], results.sort
    assert_equal 0, Economy::Ledger.balance(user)
  ensure
    user&.destroy!
  end
end
