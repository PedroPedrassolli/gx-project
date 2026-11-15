module Matches
  # O tempo do duelo (escopo 3.7: "Timer por turno e por decisão" e "Tempo máximo de duelo
  # (padrão 60 min), com desempate por LP"). Cada pergunta tem um prazo; o jogador da vez tem
  # ainda um banco de tempo para o turno inteiro, que só gasta enquanto a pergunta é dele.
  # Quem deixa o prazo passar perde (é também o que acontece com quem cai e não volta).
  #
  # O dono da sala escolhe o tempo de resposta e o do duelo (GXP-80, ADR 0011 item 18); a
  # partida guarda a escolha. Nulo é sem limite: não há prazo, banco nem fim pelo relógio.
  module Clock
    # Segundos por decisão => banco do turno, em segundos. 90 s e 5 min eram o tempo fixo de
    # antes e continuam o padrão; os outros mantêm o banco perto de 3 a 4 decisões.
    DECISIONS = { 30 => 120, 60 => 240, 90 => 300, 180 => 600 }.freeze
    # Minutos de duelo.
    DUELS = [ 20, 40, 60, 90 ].freeze

    module_function

    # O prazo de uma pergunta aberta agora: o da decisão ou, se for menos, o que sobra do
    # banco. Sem limite de resposta, não há prazo.
    def deadline(now, turn_player:, bank:, decision:)
      return if decision.nil?

      now + (turn_player ? [ decision, bank ].min : decision).seconds
    end

    # O banco do turno que começa (0 quando a resposta não tem limite: ele nem é usado).
    def turn_bank(decision) = decision ? DECISIONS.fetch(decision) : 0
  end
end
