module Duel
  # Transforma a escolha do jogador (o JSON da tela) nos bytes que a engine espera para cada
  # pergunta, no formato do playerop.cpp da versão fixada. Aqui só se confere a forma; se a
  # escolha não vale no duelo, a engine recusa e a Duel::Session avisa (InvalidResponse).
  module ResponseEncoder
    class InvalidChoice < StandardError; end

    # Na ordem dos códigos da engine: summon é 0, spsummon é 1...
    IDLE_COMMANDS = %w[summon spsummon reposition mset sset activate battle end shuffle].freeze
    BATTLE_COMMANDS = %w[activate attack main2 end].freeze
    POSITIONS = [ 0x1, 0x2, 0x4, 0x8 ].freeze
    MAX_ITEMS = 60

    module_function

    # choice: Hash com as chaves de cada pergunta (command, index, yes, indexes...).
    def encode(prompt_type, choice)
      case prompt_type.to_sym
      when :select_idlecmd then command(IDLE_COMMANDS, choice)
      when :select_battlecmd then command(BATTLE_COMMANDS, choice)
      when :select_chain, :select_option, :announce_number then int(integer(choice[:index], -1..MAX_ITEMS))
      when :select_effectyn, :select_yesno then int(choice[:yes] == true ? 1 : 0)
      when :select_card, :select_tribute, :select_sum then cards(choice)
      when :select_unselect_card then unselect(choice)
      when :select_position then int(one_of(choice[:position], POSITIONS))
      when :select_place, :select_disfield then list(choice[:places], 0..255).pack("C*")
      when :select_counter then list(choice[:counts], 0..255).pack("s<*")
      when :sort_card, :sort_chain then choice[:order].nil? ? [ -1 ].pack("c") : list(choice[:order], 0..MAX_ITEMS).pack("C*")
      when :announce_race then [ integer(choice[:mask], 0..(2**63 - 1)) ].pack("Q<")
      when :announce_attrib, :announce_card then [ integer(choice[:mask] || choice[:code], 0..(2**32 - 1)) ].pack("L<")
      when :rock_paper_scissors then int(integer(choice[:hand], 1..3))
      else raise InvalidChoice, "pergunta desconhecida: #{prompt_type}"
      end
    end

    def int(value) = [ value ].pack("l<")

    # Comandos da fase principal e da batalha: (índice << 16) | comando.
    def command(names, choice)
      code = names.index(choice[:command].to_s) || raise(InvalidChoice, "comando desconhecido")
      int((integer(choice[:index] || 0, 0..MAX_ITEMS) << 16) | code)
    end

    # Seleção de cartas: tipo 0 (índices de 32 bits), quantidade e os índices; -1 desiste.
    def cards(choice)
      return int(-1) if choice[:cancel] == true

      indexes = list(choice[:indexes], 0..MAX_ITEMS)
      [ 0, indexes.size, *indexes ].pack("l<L<L<*")
    end

    # Uma carta por vez: quantidade (1) e o índice; -1 encerra ou desiste.
    def unselect(choice)
      index = integer(choice[:index], -1..MAX_ITEMS)
      index == -1 ? int(-1) : [ 1, index ].pack("l<l<")
    end

    def integer(value, range)
      number = Integer(value, exception: false) if value.is_a?(Integer) || value.is_a?(String)
      raise InvalidChoice, "número fora do esperado" unless number && range.cover?(number)

      number
    end

    def one_of(value, options)
      options.include?(value) ? value : raise(InvalidChoice, "opção desconhecida")
    end

    def list(values, range)
      raise InvalidChoice, "lista fora do esperado" unless values.is_a?(Array) && values.size.between?(1, MAX_ITEMS)

      values.map { |value| integer(value, range) }
    end
  end
end
