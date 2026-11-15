module Economy
  # O nível do jogador (ADR 0005 item 6): a fonte não traz a regra do jogo de referência, então
  # sobe 1 nível a cada 1.000 DP ganhos (não gastos), do 1 ao 99.
  module Level
    DP_PER_LEVEL = 1_000
    MAX = 99

    module_function

    def for(dp_earned) = (1 + (dp_earned / DP_PER_LEVEL)).clamp(1, MAX)
  end
end
