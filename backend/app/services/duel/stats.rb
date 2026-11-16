module Duel
  # As estatísticas do duelo (GXP-87): o que cada time fez, contado das mensagens da engine,
  # para os bônus de DP (Anexo A do escopo) e os desafios. Fica num Hash que vai para o banco
  # (matches.stats) e volta a cada jogada: "teams" tem as contas de cada time e "state", o que
  # é preciso lembrar entre uma mensagem e outra (PV, corrente aberta, batalha, cartas no
  # campo). As chaves são texto porque o jsonb devolve assim.
  #
  # Quem fez o quê: a engine não diz de quem é o efeito que destruiu ou descartou uma carta.
  # Aqui vale o dono do elo da corrente que está resolvendo; fora de corrente, o oponente do
  # dono da carta.
  class Stats
    # Mensagens (MSG_*) que a mesa não mostra e por isso a Duel::Events não lê.
    CHAIN_SOLVING = 72
    EQUIP = 93
    LP_UPDATE = 94
    ADD_COUNTER = 101
    REMOVE_COUNTER = 102
    BATTLE = 111
    ATTACK_DISABLED = 112
    # Motivos de uma carta mudar de lugar (REASON_*).
    DESTROY = 0x1
    RELEASE = 0x2
    FOR_SUMMON = 0x10
    IN_BATTLE = 0x20
    EFFECT = 0x40
    COST = 0x80
    DISCARD = 0x4000
    FUSION_MATERIAL = 0x40000
    RITUAL_MATERIAL = 0x100000
    # Tipos de carta (TYPE_*).
    SPELL = 0x2
    TRAP = 0x4
    FUSION = 0x40
    RITUAL = 0x80
    UNION = 0x400
    TOKEN = 0x4000
    QUICK_PLAY = 0x10000
    TOON = 0x400000
    # A moeda: a dica da opção escolhida (HINT_OPSELECTED), os textos de cara e coroa e os lados.
    OPTION_SELECTED = 4
    CALLED_HEADS = 60
    CALLED_TAILS = 61
    HEADS = 1
    TAILS = 0
    # O marcador de magia (COUNTER_SPELL), sem os bits de opção.
    SPELL_COUNTER = 0x1
    COUNTER_MASK = 0xfff
    MONSTER_ZONE = Events::FIELD.first
    SPELL_ZONE = Events::FIELD.last
    MONSTER_ZONES = 5

    # types: o tipo (TYPE_*) de uma carta pelo código; o padrão lê do banco de cartas da engine.
    def initialize(data = nil, starting_lp: 8000, types: ->(code) { Engine.cards.find(code)&.type.to_i })
      @data = data.presence || { "teams" => [ {}, {} ], "state" => blank_state(starting_lp) }
      @state = @data["state"]
      @types = types
    end

    def to_h = @data

    # As contas de um time no fim do duelo, com o que só se sabe no fim: se o turno final
    # começou com menos PV que o oponente (virada), se o último golpe tirou exatamente o PV
    # que restava e qual carta deu o golpe final em batalha.
    def team(team)
      hit = @state["last_hit"]
      mine = hit && hit["team"] == team
      @data["teams"][team].merge("reversal" => @state["turn_lp"][team] < @state["turn_lp"][1 - team],
                                 "exact_finish" => mine && hit["exact"] || false, "finisher" => (hit["code"] if mine))
    end

    # Conta as mensagens de uma jogada, na ordem em que a engine mandou.
    def update(messages) = apply(messages.filter_map { |message| Events.event(message) || extra_event(message) })

    # Cada evento vai para o método com o nome dele (on_move, on_summon...); os que não
    # interessam não têm método.
    def apply(events)
      events.each { |event| public_send("on_#{event[:type]}", event) if respond_to?("on_#{event[:type]}") }
      2.times { |team| look_at_field(team) }
      self
    end

    # O maior ATK virado para cima do time agora (a mesa consultada na engine).
    def sample(team, monsters)
      monsters.compact.each { |card| max(team, "max_atk", card[:atk].to_i) if card[:position].to_i.anybits?(Events::FACE_UP) }
    end

    def on_turn(event)
      @state.merge!("turn_team" => event[:team], "turn_lp" => @state["lp"].dup, "turn_damage" => [ 0, 0 ], "hitting" => false)
    end

    def on_phase(_event) = @state["hitting"] = false

    def on_move(event)
      from, to, reason = event.values_at(:from, :to, :reason)
      follow_field(event[:code], from, to)
      owner = from[:controller]
      by = @state["resolving"] || (1 - owner)
      count_material(by, owner, reason)
      count_destroyed(by, owner, from, reason)
      count_banished(by, owner, from) if to[:location] == Events::BANISHED && reason.anybits?(EFFECT) && reason.nobits?(COST)
      count_resolving(owner, from, to, reason) if @state["resolving"]
    end

    def on_position(event)
      place = key(event)
      @state["field"][place] = event[:code] if @state["field"].key?(place)
      @state["revealed"] = place if event[:location] == SPELL_ZONE && event[:to].anybits?(Events::FACE_UP)
    end

    def on_summon(event)
      team, code = event.values_at(:controller, :code)
      remember(team, "summoned", code)
      case event[:kind]
      when "normal"
        add(team, "normal_summons")
        add(team, "tribute_summons") if @state["tributed"][team]
      when "flip" then add(team, "flip_summons")
      else count_special_summon(team, code)
      end
      %w[tributed fused ritual].each { |flag| @state[flag][team] = false }
    end

    def on_chain(event)
      team, code, link = event.values_at(:controller, :code, :link)
      @state["links"][link.to_s] = { "team" => team, "code" => code }
      @state["hitting"] = false
      @state["links"].each_value { |each| max(each["team"], "max_chain", link) }
      count_activation(team, code) if @state["revealed"] == key(event)
      @state["revealed"] = nil
    end

    def on_chain_solving(event) = @state["resolving"] = @state["links"].dig(event[:link].to_s, "team")

    # O elo resolveu: a carta foi usada (se não foi negada).
    def on_chain_solved(event)
      link = @state["links"][event[:link].to_s]
      remember(link["team"], "used", link["code"]) if link && !link["negated"]
      @state["resolving"] = nil
    end

    # A engine pode avisar duas vezes do mesmo elo (ativação e efeito negados): conta uma.
    def on_chain_negated(event)
      link = @state["links"][event[:link].to_s]
      return if link.nil? || link["negated"]

      link["negated"] = true
      add(1 - link["team"], "negations")
    end

    def on_chain_end(_event) = @state.merge!("links" => {}, "resolving" => nil)

    # Só o jogador da vez ataca: quem negou o ataque foi o outro.
    def on_attack_disabled(_event) = add(1 - @state["turn_team"], "negations")

    def on_battle(event)
      attacker, target = event.values_at(:attacker, :target)
      @state["battle"] = { "team" => attacker[:controller], "code" => @state["field"][key(attacker)], "direct" => target.nil? }
      @state["hitting"] = true
      max(attacker[:controller], "max_atk", event[:attack])
      max(target[:controller], "max_atk", event[:target_attack]) if target
    end

    def on_lp(event)
      team, amount = event.values_at(:team, :amount)
      before = @state["lp"][team]
      case event[:kind]
      when "damage" then count_damage(team, amount, before)
      when "recover" then add(team, "recovered", amount)
      end
      @state["lp"][team] = { "recover" => before + amount, "set" => amount }.fetch(event[:kind]) { [ before - amount, 0 ].max }
      2.times { |each| max(each, "max_lp_deficit", @state["lp"][1 - each] - @state["lp"][each]) }
    end

    # O jogador disse cara ou coroa antes de a moeda cair.
    def on_coin_call(event) = @state["coin_call"][event[:team]] = event[:call]

    # Acerto é a moeda cair no lado que o jogador disse; na carta que não pergunta, cara. O
    # que conta é a sequência de acertos. (O dado não entra: não há como saber o que é ganhar.)
    def on_coin(event)
      team = event[:team]
      call = @state["coin_call"][team] || HEADS
      @state["coin_call"][team] = nil
      event[:results].each do |result|
        @state["coins"][team] = result == call ? @state["coins"][team] + 1 : 0
        max(team, "coin_streak", @state["coins"][team])
      end
    end

    def on_equip(event)
      return unless @types.call(@state["field"][key(event)].to_i).anybits?(UNION)

      add(event[:controller], "union_equips")
      add(event[:controller], "unions")
    end

    def on_counter(event)
      add(event[:controller], event[:added] ? "spell_counters_added" : "spell_counters_used", event[:count]) if event[:spell]
    end

    private

    def blank_state(lp)
      { "lp" => [ lp, lp ], "turn_lp" => [ lp, lp ], "turn_team" => 0, "turn_damage" => [ 0, 0 ], "links" => {}, "resolving" => nil,
        "battle" => nil, "hitting" => false, "field" => {}, "revealed" => nil, "tributed" => [ false, false ],
        "fused" => [ false, false ], "ritual" => [ false, false ], "coins" => [ 0, 0 ], "coin_call" => [ nil, nil ],
        "last_hit" => nil }
    end

    # As mensagens que só as estatísticas leem, no mesmo formato de evento da Duel::Events.
    def extra_event(message)
      reader = ByteReader.new(message.payload)
      case message.type
      when CHAIN_SOLVING then { type: "chain_solving", link: reader.u8 }
      when EQUIP then { type: "equip", **reader.location }
      when LP_UPDATE then { type: "lp", kind: "set", team: reader.u8, amount: reader.u32 }
      when ADD_COUNTER, REMOVE_COUNTER
        spell = (reader.u16 & COUNTER_MASK) == SPELL_COUNTER
        { type: "counter", added: message.type == ADD_COUNTER, spell:, controller: reader.u8, location: reader.u8, sequence: reader.u8,
          count: reader.u16 }
      when BATTLE then battle_event(reader)
      when ATTACK_DISABLED then { type: "attack_disabled" }
      when MessageParser::HINT then coin_call(reader)
      end
    end

    # A dica "o jogador escolheu cara" (60) ou "coroa" (61), que a engine manda antes da moeda.
    def coin_call(reader)
      kind, team, option = reader.u8, reader.u8, reader.u64
      { type: "coin_call", team:, call: option == CALLED_HEADS ? HEADS : TAILS } if kind == OPTION_SELECTED && [ CALLED_HEADS, CALLED_TAILS ].include?(option)
    end

    # O cálculo de dano: quem ataca, com que ATK, e o alvo (nil no ataque direto).
    def battle_event(reader)
      attacker = reader.location
      attack = reader.u32
      reader.bytes(5) # DEF de quem ataca e se ele é destruído
      target = reader.location
      { type: "battle", attacker:, attack:, target: (target if target[:location].positive?), target_attack: reader.u32 }
    end

    def add(team, name, amount = 1) = @data["teams"][team][name] = @data["teams"][team].fetch(name, 0) + amount
    def max(team, name, value) = @data["teams"][team][name] = [ @data["teams"][team].fetch(name, 0), value ].max

    # Lista sem repetição (cartas invocadas e cartas usadas).
    def remember(team, name, code)
      list = (@data["teams"][team][name] ||= [])
      list << code unless list.include?(code)
    end

    def key(place) = place.values_at(:controller, :location, :sequence).join(":")
    def on_field?(place) = Events::FIELD.include?(place[:location])

    # As cartas no campo, pelo lugar: a mensagem de ataque e a de equipar só dizem o lugar.
    def follow_field(code, from, to)
      @state["field"].delete(key(from)) if on_field?(from)
      return unless on_field?(to)

      @state["field"][key(to)] = code
      @state["revealed"] = key(to) if to[:location] == SPELL_ZONE && to[:position].anybits?(Events::FACE_UP)
    end

    # Tributos e materiais: a invocação que vem depois é de Tributo, de Fusão ou de Ritual.
    def count_material(by, owner, reason)
      if reason.anybits?(RELEASE)
        add(owner, "tributes")
        @state["tributed"][owner] = true if reason.anybits?(FOR_SUMMON)
      end
      @state["fused"][by] = true if reason.anybits?(FUSION_MATERIAL)
      @state["ritual"][by] = true if reason.anybits?(RITUAL_MATERIAL)
    end

    # Cartas do oponente destruídas: em batalha (sempre monstros) ou por efeito.
    def count_destroyed(by, owner, from, reason)
      return unless reason.anybits?(DESTROY)
      return add(1 - owner, "battle_destroyed") if reason.anybits?(IN_BATTLE)
      return unless reason.anybits?(EFFECT) && by != owner

      add(by, "effect_destroyed")
      add(by, "effect_destroyed_monsters") if from[:location] == MONSTER_ZONE
    end

    def count_banished(by, owner, from)
      return if by == owner

      add(by, "banished")
      add(by, "banished_monsters") if from[:location] == MONSTER_ZONE
    end

    # O que só conta quando um efeito de alguém está resolvendo: descartar da mão ou do deck
    # do oponente, devolver cartas para a mão e tomar o controle de um monstro.
    def count_resolving(owner, from, to, reason)
      by = @state["resolving"]
      origin = from[:location]
      if by != owner
        add(by, "hand_discards") if origin == Events::HAND && reason.anybits?(DISCARD)
        add(by, "deck_discards") if origin == Events::DECK && to[:location] == Events::GRAVE
      end
      add(by, "returned") if to[:location] == Events::HAND && (on_field?(from) || origin == Events::GRAVE)
      add(by, "controls_taken") if origin == MONSTER_ZONE && to[:location] == MONSTER_ZONE && to[:controller] == by && by != owner
    end

    def count_special_summon(team, code)
      type = @types.call(code)
      add(team, "special_summons")
      add(team, "tokens") if type.anybits?(TOKEN)
      add(team, "unions") if type.anybits?(UNION)
      add(team, "fusion_summons") if type.anybits?(FUSION) && @state["fused"][team]
      add(team, "ritual_summons") if type.anybits?(RITUAL) && @state["ritual"][team]
    end

    # A magia ou armadilha que acabou de ser virada para cima e entrou na corrente foi ativada
    # (o efeito de uma carta que já estava aberta não conta como ativar a carta).
    def count_activation(team, code)
      type = @types.call(code)
      add(team, "traps") if type.anybits?(TRAP)
      return unless type.anybits?(SPELL)

      add(team, "spells")
      add(team, "quick_spells_on_opponent_turn") if type.anybits?(QUICK_PLAY) && @state["turn_team"] != team
    end

    # O dano que o time sofreu. De batalha, logo depois do cálculo de dano; senão, de efeito
    # (o do próprio efeito não conta para ninguém).
    def count_damage(team, amount, before)
      add(team, "damage_taken", amount)
      battle = @state["battle"] if @state["hitting"]
      return if battle.nil? && @state["resolving"] == team

      dealer = 1 - team
      add(dealer, "damage", amount)
      add(dealer, battle ? "battle_damage" : "effect_damage", amount)
      max(dealer, "max_hit", amount)
      @state["turn_damage"][dealer] += amount
      max(dealer, "max_turn_damage", @state["turn_damage"][dealer])
      count_battle_damage(dealer, amount, battle) if battle
      @state["last_hit"] = { "team" => dealer, "exact" => amount == before, "code" => (battle["code"] if battle && battle["team"] == dealer) } if amount >= before
    end

    # O dano de batalha: refletido (quem atacou foi quem sofreu) ou do ataque do próprio time.
    def count_battle_damage(dealer, amount, battle)
      if battle["team"] != dealer
        add(dealer, "reflected_damage", amount)
        return max(dealer, "max_reflected", amount)
      end

      max(dealer, "max_attack_damage", amount)
      return unless battle["direct"]

      add(dealer, "direct_damage", amount)
      add(dealer, "toon_direct_damage", amount) if @types.call(battle["code"].to_i).anybits?(TOON)
    end

    # Todas as zonas de monstro ocupadas, e três cartas iguais (sem ficha) do mesmo lado.
    def look_at_field(team)
      mine = @state["field"].select { |place, _code| place.start_with?("#{team}:") }
      @data["teams"][team]["full_field"] = true if mine.keys.count { |place| place.start_with?("#{team}:#{MONSTER_ZONE}:") } >= MONSTER_ZONES
      @data["teams"][team]["same_three"] = true if mine.values.tally.any? { |code, count| count >= 3 && @types.call(code).nobits?(TOKEN) }
    end
  end
end
