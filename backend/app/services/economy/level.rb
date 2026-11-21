module Economy
  # O nível do jogador (ADR 0005 item 6): a fonte não traz a regra do jogo de referência, então
  # sobe 1 nível a cada 300 DP ganhos em duelos (não gastos), do 1 ao 99. Era a cada 1.000; o
  # Pedro pediu tudo bem mais fácil em 20/11/2026 (o nível 50 chega em uns 25 duelos).
  module Level
    DP_PER_LEVEL = 300
    MAX = 99

    module_function

    def for(dp_earned) = (1 + (dp_earned / DP_PER_LEVEL)).clamp(1, MAX)
  end
end
