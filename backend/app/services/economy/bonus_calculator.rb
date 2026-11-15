module Economy
  # Os bônus de DP do fim do duelo (escopo 3.5, Anexo A; ADR 0005 item 4): recebe o que se sabe
  # do duelo e devolve as linhas (chave, texto e DP). Não lê banco nem relógio. Valores do jogo
  # de referência, pela Yugipedia (página de bônus e desafios); entram aqui os que saem do fim
  # do duelo, e os que precisam das estatísticas do duelo inteiro vêm no GXP-87.
  #
  # stats: result (:win, :loss ou :draw), turns, level e opponent_level (1 a 99), engine_win
  # (o duelo acabou na engine, não por desistência ou tempo), win_reason (o da engine), lp e
  # deck (do jogador, no fim) e opponent_turn (acabou no turno do oponente).
  module BonusCalculator
    # Os motivos de vitória da engine (ygopro-core e constant.lua dos scripts).
    DECK_OUT = 2
    SPECIAL_WINS = { 0x10 => [ "exodia", "Vitória com Exodia", 50 ], 0x11 => [ "final_countdown", "Vitória com Contagem Final", 50 ],
                     0x15 => [ "destiny_board", "Vitória com o Quadro do Destino", 100 ], 0x16 => [ "last_turn", "Vitória com Último Turno", 50 ] }.freeze

    module_function

    def lines(stats)
      lines = []
      add = ->(key, label, dp) { lines << { key:, label:, dp: } if dp.positive? }
      add.call("level", "Nível #{stats[:level]}", 2 * stats[:level])
      add.call("loss", "Derrota", 10) if stats[:result] == :loss
      add.call("draw", "Empate", 50) if stats[:result] == :draw
      won = stats[:result] == :win
      add.call("turns", "#{stats[:turns]} turnos", (won ? 2 : 1) * stats[:turns])
      return lines unless won

      add.call("network_win", "Vitória em rede", 50)
      # Duelista: 90 por faixa de nível do oponente (1 a 10, uma a cada 10 níveis).
      add.call("duelist", "Oponente de nível #{stats[:opponent_level]}", 90 * (((stats[:opponent_level] - 1) / 10) + 1))
      win_forms(stats, add) if stats[:engine_win]
      lines
    end

    # As formas de vencer contam só na vitória da engine: desistência e tempo não valem.
    def win_forms(stats, add)
      lp = stats[:lp]
      deck = stats[:deck]
      add.call("no_cards", "Oponente sem cartas para comprar", 20) if stats[:win_reason] == DECK_OUT
      add.call("quick", "Vitória em até 5 turnos", 10) if stats[:turns] <= 5
      add.call("opponent_turn", "Vitória no turno do oponente", 20) if stats[:opponent_turn]
      add.call("low_lp", "Vitória com menos de 1.000 PV", 20) if lp < 1_000
      add.call("very_low_lp", "Vitória com menos de 100 PV", 100) if lp < 100
      add.call("high_lp", "Vitória com mais de 20.000 PV", 100) if lp > 20_000
      add.call("konami", "Vitória com 5.730 PV", 573) if lp == 5_730
      add.call("low_deck", "Vitória com menos de 10 cartas no deck", 20) if deck < 10
      add.call("empty_deck", "Vitória com o deck vazio", 100) if deck.zero?
      key, label, dp = SPECIAL_WINS[stats[:win_reason]]
      add.call(key, label, dp) if key
    end
  end
end
