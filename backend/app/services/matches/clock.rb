module Matches
  # O tempo do duelo (escopo 3.7: "Timer por turno e por decisão" e "Tempo máximo de duelo
  # (padrão 60 min), com desempate por LP"). Cada pergunta tem um prazo; o jogador da vez tem
  # ainda um banco de tempo para o turno inteiro, que só gasta enquanto a pergunta é dele.
  # Quem deixa o prazo passar perde (é também o que acontece com quem cai e não volta).
  module Clock
    DECISION = 90.seconds
    TURN = 5.minutes
    DUEL = 60.minutes

    module_function

    # O prazo de uma pergunta aberta agora: o da decisão ou, se for menos, o que sobra do banco.
    def deadline(now, turn_player:, bank:) = now + (turn_player ? [ DECISION, bank.seconds ].min : DECISION)
  end
end
