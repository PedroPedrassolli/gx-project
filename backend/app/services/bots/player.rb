module Bots
  # O computador dos duelos contra personagens (escopo 3.10; ADR 0013). Responde às perguntas
  # da engine olhando só a mesa que um jogador veria do lado dele (Duel::View): a mão e o deck
  # do oponente e as cartas viradas para baixo ficam escondidos, como para qualquer um.
  #
  # Joga por regras simples: invoca o monstro mais forte, ataca o que consegue destruir, baixa
  # as armadilhas e ativa na hora em que o oponente ataca ou invoca. O que a regra não sabe
  # decidir vai para o robô que escolhe ao acaso (Bots::RandomPlayer). skill de 1 a 3: quanto
  # menor, mais vezes ele erra de propósito (escolhe ao acaso) e mais vezes deixa passar a
  # hora de ativar uma armadilha.
  class Player
    MISTAKES = { 1 => 0.2, 2 => 0.07, 3 => 0.0 }.freeze
    RESPONDS = { 1 => 0.6, 2 => 0.9, 3 => 1.0 }.freeze
    # Ações na fase principal num mesmo pedido: depois disso, vai para a batalha ou encerra (um
    # efeito que dá para ativar sem fim não prende o turno).
    MAX_ACTIONS = 15

    # Tipos de carta e posições (TYPE_* e POS_* do ocgapi_constants.h).
    MONSTER = 0x1
    TRAP = 0x4
    QUICKPLAY = 0x10000
    EQUIP = 0x40000
    COUNTER = 0x100000
    ATTACK = 0x1
    DEFENSE = 0x4

    # As dicas da pergunta (HINTMSG_*; duel/hints.ts no front). Escolher o alvo do ataque, e as
    # escolhas que são boas para o dono da carta: pôr na mão, invocar, equipar, pôr no campo.
    # As outras (destruir, banir, descartar, tributar...) são ruins para o dono.
    ATTACK_TARGET = 549
    GOOD_FOR_OWNER = [ 506, 508, 509, 518, 527 ].freeze

    # As perguntas que têm regra aqui; as outras vão para o robô.
    RULES = %i[select_idlecmd select_battlecmd select_card select_unselect_card select_tribute select_chain
               select_effectyn select_yesno select_position sort_card sort_chain].freeze

    # Cartas que só valem a pena em certa hora (passcode => quando).
    CAREFUL = {
      53129443 => :behind_in_monsters, # Dark Hole: destrói todos os monstros
      19613556 => :behind_in_spells,   # Heavy Storm: destrói todas as magias e armadilhas
      42703248 => :behind_in_spells,   # Giant Trunade: devolve todas as magias e armadilhas
      5318639 => :their_spells,        # Mystical Space Typhoon
      45939841 => :their_spells,       # Twister
      60082869 => :their_spells        # Dust Tornado
    }.freeze

    # codes: as cartas do deck do computador, para declarar um nome quando a carta pede.
    def initialize(team:, skill:, random:, codes:)
      @team = team
      @skill = skill
      @random = random
      @guesser = RandomPlayer.new(random, codes)
      @activated = Hash.new(0)
    end

    # A escolha para a pergunta da mesa (o JSON que a tela mandaria).
    def choose(view)
      new_turn(view[:turn])
      @view = view
      prompt = view[:prompt]
      type = prompt[:type].to_sym
      return guess(prompt) if RULES.exclude?(type) || @random.rand < MISTAKES.fetch(@skill)

      send(type, prompt)
    end

    # Ao acaso entre as opções válidas.
    def guess(prompt) = @guesser.choose(prompt)

    private

    # As contas da fase principal valem por turno.
    def new_turn(turn)
      return if turn == @turn

      @turn = turn
      @actions = 0
      @activated.clear
    end

    # Fase principal: uma ação por pergunta, até não ter mais o que fazer.
    def select_idlecmd(prompt)
      @actions += 1
      action = (special_summon(prompt) || activate(prompt) || normal_summon(prompt) || set_monster(prompt) ||
                set_spell_or_trap(prompt) || reposition(prompt) if @actions <= MAX_ACTIONS)
      action || end_main(prompt)
    end

    def special_summon(prompt)
      index = best_index(prompt[:spsummonable]) { |card| attack_of(card[:code]) }
      { command: "spsummon", index: } if index
    end

    # Magias e efeitos de monstro, menos o que é para a hora certa: armadilha fica para o turno
    # do oponente e a carta de CAREFUL só quando vale a pena.
    def activate(prompt)
      index = prompt[:activatable].each_index.find do |i|
        card = prompt[:activatable][i]
        !type?(card[:code], TRAP) && worth_it?(card[:code]) && @activated[card.values_at(:code, :description)] < 2
      end
      return unless index

      @activated[prompt[:activatable][index].values_at(:code, :description)] += 1
      { command: "activate", index: }
    end

    def worth_it?(code)
      return monsters(mine).any? { |card| !card[:face_down] } if type?(code, EQUIP)

      case CAREFUL[code]
      when :behind_in_monsters then monsters(theirs).size > monsters(mine).size
      when :behind_in_spells then spells(theirs).size > spells(mine).size
      when :their_spells then spells(theirs).any?
      else true
      end
    end

    # O mais forte. Com Tributo, só se fica mais forte que o melhor que já está no campo; mais
    # fraco que o mais forte do oponente, só se não der para baixar um monstro no lugar.
    def normal_summon(prompt)
      strongest = monsters(mine).map { |card| card[:atk].to_i }.max.to_i
      options = prompt[:summonable].each_index.reject do |i|
        code = prompt[:summonable][i][:code]
        level_of(code) >= 5 && attack_of(code) <= strongest
      end
      index = options.max_by { |i| attack_of(prompt[:summonable][i][:code]) }
      return unless index
      return if attack_of(prompt[:summonable][index][:code]) < threat && prompt[:msetable].any? { |card| level_of(card[:code]) <= 4 }

      { command: "summon", index: }
    end

    # Baixa o de mais DEF entre os que não pedem Tributo.
    def set_monster(prompt)
      options = prompt[:msetable].each_index.select { |i| level_of(prompt[:msetable][i][:code]) <= 4 }
      index = options.max_by { |i| defense_of(prompt[:msetable][i][:code]) }
      { command: "mset", index: } if index
    end

    # Baixa armadilha e Magia Rápida; as outras magias ficam na mão para quando servirem.
    def set_spell_or_trap(prompt)
      index = prompt[:ssetable].each_index.find { |i| type?(prompt[:ssetable][i][:code], TRAP | QUICKPLAY) }
      { command: "sset", index: } if index
    end

    # Antes da batalha, vira para o ataque quem vence o mais forte do oponente; depois dela, vira
    # para a defesa quem perderia.
    def reposition(prompt)
      index = prompt[:repositionable].each_index.find do |i|
        card = mine[:monsters][prompt[:repositionable][i][:sequence]]
        next false unless card

        if @view[:phase] == "main1" then card[:defense] && card[:atk].to_i > threat
        else !card[:defense] && card[:atk].to_i < threat && card[:def].to_i > card[:atk].to_i
        end
      end
      { command: "reposition", index: } if index
    end

    def end_main(prompt)
      return { command: "battle" } if prompt[:to_bp] && @view[:phase] == "main1" && monsters(mine).any? { |card| !card[:defense] }
      return { command: "end" } if prompt[:to_ep]

      guess(prompt)
    end

    # Ataca quando destrói algo sem perder o monstro (ou ataca direto). O alvo fica guardado
    # para a pergunta seguinte, a do alvo do ataque.
    def select_battlecmd(prompt)
      attack = prompt[:attackable].each_index.filter_map { |i| plan_attack(prompt[:attackable][i], i) }.max_by(&:last)
      if attack
        @target = attack[1]
        return { command: "attack", index: attack.first }
      end
      return { command: "main2" } if prompt[:to_m2]
      return { command: "end" } if prompt[:to_ep]

      { command: "attack", index: 0 }
    end

    # [índice, alvo (nil é direto), quanto vale]. Nil quando não vale atacar.
    def plan_attack(attacker, index)
      power = mine[:monsters][attacker[:sequence]]&.dig(:atk).to_i
      targets = theirs[:monsters].each_with_index.filter_map { |card, sequence| [ sequence, card ] if card }
      return [ index, nil, power ] if targets.empty?

      sequence, value = targets.filter_map { |seq, card| [ seq, target_value(card, power) ] }.select(&:last).max_by(&:last)
      [ index, sequence, value ] if sequence
    end

    # Quanto vale atacar a carta: o ATK dela quando ela cai e o atacante fica. Virada para
    # baixo, só um atacante forte arrisca. Nil quando não vale.
    def target_value(card, power)
      return (power >= 1900 ? 1 : nil) if card[:face_down]

      guard = card[:defense] ? card[:def].to_i : card[:atk].to_i
      card[:atk].to_i + 1 if power > guard
    end

    # O alvo do ataque é o planejado (ou o mais fraco). Nas outras, as de melhor nota.
    def select_card(prompt)
      cards = prompt[:cards]
      if prompt[:hint] == ATTACK_TARGET
        planned = cards.index { |card| card[:controller] != @team && card[:sequence] == @target }
        return { indexes: [ planned || cards.each_index.min_by { |i| value_of(cards[i]) } ] }
      end
      ranked = cards.each_index.sort_by { |i| -score(cards[i], prompt[:hint]) }
      { indexes: ranked.first(prompt[:min].clamp(1, cards.size)) }
    end

    # Uma carta por vez, a de melhor nota, até a engine deixar concluir.
    def select_unselect_card(prompt)
      return { index: -1 } if prompt[:finishable] || prompt[:selectable].empty?

      { index: prompt[:selectable].each_index.max_by { |i| score(prompt[:selectable][i], prompt[:hint]) } }
    end

    # Nota para escolher a carta: o valor dela, a favor de quem a escolha é boa.
    def score(card, hint)
      value = value_of(card)
      good_for_owner = GOOD_FOR_OWNER.include?(hint)
      (card[:controller] == @team) == good_for_owner ? value : -value
    end

    # Monstro vale o ATK (o da mesa, se está à vista); o resto, um valor médio.
    def value_of(card)
      on_field = side(card[:controller])[:monsters][card[:sequence]] if card[:location] == Duel::Query::MONSTERS
      return on_field[:atk].to_i if on_field&.key?(:atk)
      return 1200 if card[:code].to_i.zero?

      type?(card[:code], MONSTER) ? attack_of(card[:code]) : 1000
    end

    # Tributa os mais fracos.
    def select_tribute(prompt)
      indexes = RandomPlayer.tributes(prompt, prompt[:cards].each_index.sort_by { |i| value_of(prompt[:cards][i]) })
      indexes ? { indexes: } : guess(prompt)
    end

    # Gatilho do próprio computador (spe_count) é quase sempre bom. Do resto, ativa armadilha e
    # Magia Rápida quando o oponente ataca ou invoca; Contra-Armadilha quando ele ativa algo.
    def select_chain(prompt)
      chains = prompt[:chains]
      return { index: 0 } if prompt[:forced] || prompt[:spe_count].to_i.positive?

      types = response_types
      index = chains.index { |card| type?(card[:code], types) } if types && @random.rand < RESPONDS.fetch(@skill)
      { index: index || -1 }
    end

    # Os tipos de carta que valem para responder ao último lance do oponente, ou nil.
    def response_types
      event = @view[:events].to_a.reverse.find { |item| %w[attack summon chain chain_solved].include?(item[:type]) }
      return unless event && event[:type] != "chain_solved"

      controller = event[:type] == "attack" ? event.dig(:attacker, :controller) : event[:controller]
      return if controller == @team

      event[:type] == "chain" ? COUNTER : TRAP | QUICKPLAY
    end

    def select_effectyn(_prompt) = { yes: true }
    def select_yesno(_prompt) = { yes: true }

    # Em ataque quando vence o mais forte do oponente ou o ATK passa a DEF; senão, em defesa.
    def select_position(prompt)
      attack = attack_of(prompt[:code]) >= threat || attack_of(prompt[:code]) >= defense_of(prompt[:code])
      preferred = attack ? [ ATTACK, DEFENSE ] : [ DEFENSE, ATTACK ]
      position = preferred.find { |bit| prompt[:positions].anybits?(bit) }
      position ? { position: } : guess(prompt)
    end

    def sort_card(_prompt) = {}
    alias sort_chain sort_card

    def mine = side(@team)
    def theirs = side(1 - @team)
    def side(team) = @view[:sides][team]
    def monsters(side) = side[:monsters].compact
    def spells(side) = [ *side[:spells], side[:field_spell] ].compact

    # O ATK do monstro mais forte do oponente com a face para cima (0 sem nenhum).
    def threat = monsters(theirs).reject { |card| card[:face_down] }.map { |card| card[:atk].to_i }.max.to_i

    def best_index(cards, &)
      cards.each_index.max_by { |i| yield cards[i] }
    end

    # Os dados da carta pela engine. Carta desconhecida (ou escondida, código 0) vale 0; ATK e
    # DEF "?" (negativos na engine) também.
    def card(code) = Duel::Engine.cards.find(code)
    def attack_of(code) = [ card(code)&.attack || 0, 0 ].max
    def defense_of(code) = [ card(code)&.defense || 0, 0 ].max
    def level_of(code) = card(code)&.level || 0
    def type?(code, flags) = (card(code)&.type || 0).anybits?(flags)
  end
end
