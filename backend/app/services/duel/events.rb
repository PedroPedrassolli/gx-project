module Duel
  # O que aconteceu no duelo, para o log, a pilha da corrente e as animações da mesa (GXP-65),
  # lido das mensagens da engine (formatos do playerop.cpp, operations.cpp e processor.cpp da
  # versão fixada). O evento guarda tudo, com os códigos; o `mask` tira o que cada lado não
  # vê, com as mesmas regras da Duel::View.
  module Events
    # Tipos de mensagem (MSG_* do ocgapi_constants.h).
    CONFIRM_CARDS = 31
    MOVE = 50
    POS_CHANGE = 53
    SET = 54
    SUMMONS = { 60 => "normal", 62 => "special", 64 => "flip" }.freeze
    CHAINING = 70
    CHAIN_SOLVED = 73
    CHAIN_END = 74
    CHAIN_NEGATED = [ 75, 76 ].freeze # o efeito negado e a ativação negada
    DRAW = 90
    LP = { 91 => "damage", 92 => "recover", 100 => "cost" }.freeze
    ATTACK = 110
    TOSSES = { 130 => "coin", 131 => "dice" }.freeze
    HAND_RES = 133

    # Locais (LOCATION_*) e posições (POS_*) da engine.
    DECK = 0x01
    HAND = 0x02
    FIELD = [ 0x04, 0x08 ].freeze
    GRAVE = 0x10
    BANISHED = 0x20
    EXTRA = 0x40
    FACE_UP = 0x1 | 0x4

    module_function

    def from(messages) = messages.filter_map { |message| event(message) }

    # Nil para a mensagem que a mesa não mostra.
    def event(message)
      type = message.type
      reader = ByteReader.new(message.payload)
      return card_event(type, reader) if [ MOVE, POS_CHANGE, SET, *SUMMONS.keys ].include?(type)
      return chain_event(type, reader) if [ CHAINING, CHAIN_SOLVED, CHAIN_END, *CHAIN_NEGATED ].include?(type)

      other_event(type, reader, message)
    end

    def card_event(type, reader)
      case type
      when MOVE then { type: "move", code: reader.u32, from: reader.location, to: reader.location, reason: reader.u32 }
      when POS_CHANGE
        { type: "position", code: reader.u32, controller: reader.u8, location: reader.u8, sequence: reader.u8,
          from: reader.u8, to: reader.u8 }
      when SET then { type: "set", code: reader.u32, **reader.location }
      else { type: "summon", kind: SUMMONS.fetch(type), code: reader.u32, **reader.location }
      end
    end

    def chain_event(type, reader)
      case type
      when CHAINING
        event = { type: "chain", code: reader.u32, **reader.location }
        reader.bytes(6) # quem, de onde e a sequência do gatilho: a carta já diz
        event.merge(description: reader.u64, link: reader.u32)
      when CHAIN_SOLVED then { type: "chain_solved", link: reader.u8 }
      when CHAIN_END then { type: "chain_end" }
      else { type: "chain_negated", link: reader.u8 }
      end
    end

    def other_event(type, reader, message)
      case type
      when MessageParser::NEW_TURN then { type: "turn", team: reader.u8 }
      when MessageParser::NEW_PHASE then { type: "phase", phase: reader.u16 }
      when MessageParser::WIN then { type: "win", **MessageParser.win(message) }
      when DRAW then { type: "draw", team: reader.u8, codes: Array.new(reader.u32) { reader.u32.tap { reader.u32 } } }
      when *LP.keys then { type: "lp", kind: LP.fetch(type), team: reader.u8, amount: reader.u32 }
      when ATTACK then { type: "attack", attacker: reader.location, target: reader.location.then { |at| at if at[:location].positive? } }
      when CONFIRM_CARDS
        { type: "reveal", team: reader.u8,
          cards: reader.list { { code: reader.u32, controller: reader.u8, location: reader.u8, sequence: reader.u32 } } }
      when *TOSSES.keys then { type: TOSSES.fetch(type), team: reader.u8, results: Array.new(reader.u8) { reader.u8 } }
      when HAND_RES then reader.u8.then { |hands| { type: "hands", hands: [ hands & 0b11, hands >> 2 ] } }
      end
    end

    # O evento como o viewer vê: sem o código da carta que ele não vê.
    def mask(event, viewer)
      case event[:type]
      when "draw" then event[:team] == viewer ? event : { type: "draw", team: event[:team], count: event[:codes].size }
      when "set" then event[:controller] == viewer ? event : event.merge(code: 0)
      when "move" then visible_move?(event, viewer) ? event : event.merge(code: 0)
      when "position" then event[:controller] == viewer || (event[:from] | event[:to]).anybits?(FACE_UP) ? event : event.merge(code: 0)
      else event
      end
    end

    # A carta que muda de lugar aparece para o dono e para quem a via antes ou passa a ver.
    def visible_move?(event, viewer)
      from, to = event.values_at(:from, :to)
      [ from, to ].any? { |place| place[:controller] == viewer && place[:location].positive? } || public?(from) || public?(to)
    end

    def public?(place)
      location = place[:location]
      return true if location == GRAVE
      return place[:position].anybits?(FACE_UP) if FIELD.include?(location) || [ BANISHED, EXTRA ].include?(location)

      false
    end
  end
end
