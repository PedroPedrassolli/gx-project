module Economy
  # Os bônus de DP do fim do duelo (escopo 3.5, Anexo A; ADR 0005): recebe o que se sabe do
  # duelo e devolve as linhas (chave, texto e DP). Não lê banco nem relógio. Valores do jogo de
  # referência, pela Yugipedia (página de bônus e desafios).
  #
  # stats: result (:win, :loss ou :draw), turns, level e opponent_level (1 a 99), challenges
  # (desafios já concluídos), engine_win (o duelo acabou na engine, não por desistência ou
  # tempo), win_reason (o da engine), lp e deck (do jogador, no fim), opponent_turn (acabou no
  # turno do oponente), duel (as contas do time, de Duel::Stats#team) e summoned, used e
  # finisher (os nomes das cartas invocadas, usadas e a do golpe final).
  #
  # Ficam de fora: Tag e Match (F5 e F6), "nenhuma zona de monstro livre" e "carta-chave do
  # oponente" (a fonte não diz como o jogo decide) e o "New Bonus" (sem condição na fonte).
  module BonusCalculator
    # Os motivos de vitória da engine (ygopro-core e constant.lua dos scripts).
    LP_ZERO = 1
    DECK_OUT = 2
    SPECIAL_WINS = { 0x10 => [ "exodia", "Vitória com Exodia", 50 ], 0x11 => [ "final_countdown", "Vitória com Contagem Final", 50 ],
                     0x15 => [ "destiny_board", "Vitória com o Quadro do Destino", 100 ], 0x16 => [ "last_turn", "Vitória com Último Turno", 50 ] }.freeze
    # Bônus 58 a 71 (invocou a carta) e 72 a 82 (usou a carta), pelo nome no catálogo.
    SUMMONED = { "Perfectly Ultimate Great Moth" => 30, "Wall Shadow" => 10, "Gate Guardian" => 30, "Blue-Eyes Ultimate Dragon" => 20,
                 "Metalzoa" => 10, "Red-Eyes Black Metal Dragon" => 10, "Valkyrion the Magna Warrior" => 30, "Dark Sage" => 30,
                 "XYZ-Dragon Cannon" => 20, "Exodia Necross" => 30, "Ojama King" => 20, "Mokey Mokey King" => 10,
                 "The Wicked Dreadroot" => 20, "Chimeratech Overdragon" => 30 }.freeze
    USED = { "Mega Ton Magical Cannon" => 10, "Yu-Jo Friendship" => 5, "Dark Scorpion Combination" => 10, "Ojama Delta Hurricane!!" => 10,
             "Blasting the Ruins" => 5, "The Law of the Normal" => 10, "Inferno Tempest" => 5, "Fuh-Rin-Ka-Zan" => 5,
             "Elemental Burst" => 20, "Dark Scorpion Retreat" => 30, "Illusion Gate" => 10 }.freeze
    SKULL_SERVANT = "Skull Servant"
    CARD_NAMES = [ *SUMMONED.keys, *USED.keys, SKULL_SERVANT ].freeze
    # "10 ou mais": 4 DP por carta (bônus 40 a 45).
    TEN_OR_MORE = { "battle_destroyed" => "cartas destruídas em batalha", "effect_destroyed" => "cartas destruídas por efeito",
                    "banished" => "cartas do oponente removidas do jogo", "hand_discards" => "cartas descartadas da mão do oponente",
                    "deck_discards" => "cartas descartadas do deck do oponente", "returned" => "cartas devolvidas para a mão" }.freeze

    module_function

    def lines(stats)
      lines = []
      add = ->(key, label, dp) { lines << { key:, label:, dp: } if dp.positive? }
      duel = stats.fetch(:duel, {})
      count = ->(name) { duel.fetch(name, 0) }
      basics(stats, add)
      feats(duel, count, add)
      cards(stats, add)
      return lines unless stats[:result] == :win

      card_use(count, add)
      win_forms(stats, duel, count, add) if stats[:engine_win]
      lines
    end

    # Bônus 02 a 11: o que todo duelo paga.
    def basics(stats, add)
      won = stats[:result] == :win
      add.call("level", "Nível #{stats[:level]}", 2 * stats[:level])
      add.call("challenges", "Desafios concluídos (#{stats[:challenges]})", 2 * stats[:challenges].to_i)
      add.call("loss", "Derrota", 10) if stats[:result] == :loss
      add.call("draw", "Empate", 50) if stats[:result] == :draw
      add.call("turns", "#{stats[:turns]} turnos", (won ? 2 : 1) * stats[:turns])
      return unless won

      add.call("network_win", "Vitória em rede", 50)
      # Duelista: 90 por faixa de nível do oponente (1 a 10, uma a cada 10 níveis).
      add.call("duelist", "Oponente de nível #{stats[:opponent_level]}", 90 * (((stats[:opponent_level] - 1) / 10) + 1))
    end

    # Bônus 32 a 36 e 40 a 50: os feitos do duelo, ganhando ou não.
    def feats(duel, count, add)
      add.call("chain", "Corrente de #{count['max_chain']} elos", 2 * count["max_chain"]) if count["max_chain"] >= 3
      add.call("max_atk", "Monstro com #{count['max_atk']} de ATK", count["max_atk"] / 500) if count["max_atk"] >= 3_000
      attack = count["max_attack_damage"]
      add.call("max_damage", "Ataque de #{attack} de dano", attack / 250) if attack >= 3_000
      add.call("reflected", "#{count['max_reflected']} de dano refletido", count["max_reflected"] / 100)
      TEN_OR_MORE.each { |name, label| add.call(name, "#{count[name]} #{label}", 4 * count[name]) if count[name] >= 10 }
      add.call("luck", "#{count['coin_streak']} acertos seguidos na moeda", 2 * count["coin_streak"]) if count["coin_streak"] >= 2
      counters = count["spell_counters_added"]
      add.call("spell_counters", "#{counters} marcadores de magia", 4 * counters) if counters >= 5
      add.call("unions", "União (#{count['unions']})", 6 * count["unions"])
      add.call("same_card", "3 cartas iguais no campo", 5) if duel["same_three"]
      add.call("full_field", "Todas as zonas de monstro ocupadas", 10) if duel["full_field"]
    end

    # Bônus 58 a 82: invocou ou usou certas cartas.
    def cards(stats, add)
      stats[:summoned].to_a.each { |name| add.call("summoned", "Invocou #{name}", SUMMONED.fetch(name, 0)) }
      stats[:used].to_a.each { |name| add.call("used", "Usou #{name}", USED.fetch(name, 0)) }
    end

    # Bônus 24 a 31: o uso de cartas no duelo que o jogador venceu.
    def card_use(count, add)
      { "spells" => [ "magias", "magia" ], "traps" => [ "armadilhas", "armadilha" ] }.each do |name, (plural, singular)|
        add.call(name, "#{count[name]} #{plural} ativadas", 2 * count[name]) if count[name] >= 10
        add.call("no_#{name}", "Vitória sem ativar #{singular}", 15) if count[name].zero?
      end
      add.call("fusion", "Invocações-Fusão (#{count['fusion_summons']})", 4 * count["fusion_summons"])
      add.call("ritual", "Invocações-Ritual (#{count['ritual_summons']})", 4 * count["ritual_summons"])
      add.call("tribute", "Invocações-Tributo (#{count['tribute_summons']})", 4 * count["tribute_summons"])
      add.call("no_special", "Vitória sem Invocação-Especial", 10) if count["special_summons"].zero?
    end

    # Bônus 12 a 23, 35, 37 a 39 e 53 a 57: as formas de vencer. Só contam na vitória da
    # engine: desistência e tempo não valem.
    def win_forms(stats, duel, count, add)
      lp_and_deck(stats, add)
      add.call("no_cards", "Oponente sem cartas para comprar", 20) if stats[:win_reason] == DECK_OUT
      add.call("quick", "Vitória em até 5 turnos", 10) if stats[:turns] <= 5
      add.call("opponent_turn", "Vitória no turno do oponente", 20) if stats[:opponent_turn]
      add.call("reversal", "Virada: começou o turno final com menos PV", 20) if duel["reversal"]
      add.call("no_damage", "Vitória sem sofrer dano", 10) if count["damage_taken"].zero?
      deficit = count["max_lp_deficit"]
      add.call("lp_deficit", "Venceu depois de ficar #{deficit} PV atrás", deficit / 250) if deficit >= 5_000
      add.call("exact", "Dano exato para zerar o PV", 10) if duel["exact_finish"] && stats[:win_reason] == LP_ZERO
      add.call("battle_only", "Vitória sem causar dano de efeito", 10) if count["effect_damage"].zero?
      add.call("effect_only", "Vitória sem causar dano de batalha", 30) if count["battle_damage"].zero?
      add.call("skull_servant", "Golpe final de #{SKULL_SERVANT}", 1) if stats[:finisher] == SKULL_SERVANT
      key, label, dp = SPECIAL_WINS[stats[:win_reason]]
      add.call(key, label, dp) if key
    end

    def lp_and_deck(stats, add)
      lp = stats[:lp]
      deck = stats[:deck]
      add.call("low_lp", "Vitória com menos de 1.000 PV", 20) if lp < 1_000
      add.call("very_low_lp", "Vitória com menos de 100 PV", 100) if lp < 100
      add.call("high_lp", "Vitória com mais de 20.000 PV", 100) if lp > 20_000
      add.call("konami", "Vitória com 5.730 PV", 573) if lp == 5_730
      add.call("low_deck", "Vitória com menos de 10 cartas no deck", 20) if deck < 10
      add.call("empty_deck", "Vitória com o deck vazio", 100) if deck.zero?
    end
  end
end
