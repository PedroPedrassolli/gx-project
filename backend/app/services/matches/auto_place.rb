module Matches
  # Escolhe sozinho a zona da carta que vai para o campo (ADR 0011, item 12), para a invocação
  # não parar numa pergunta a mais. A ordem é a que a engine usa quando joga sozinha
  # (playerop.cpp, DUEL_SIMPLE_AI): do centro para as pontas.
  module AutoPlace
    MZONE = 0x04
    SZONE = 0x08
    ORDER = [ 2, 1, 3, 0, 4 ].freeze
    # Local, primeiro bit no "flag" e ordem das zonas; a 5 das magias é a zona de campo.
    # Esses bits são do lado de quem escolhe; os do outro lado ficam 16 bits acima.
    ZONES = [ [ MZONE, 0, ORDER ], [ SZONE, 8, ORDER + [ 5 ] ] ].freeze

    module_function

    # Os bytes da resposta (jogador, local e sequência de cada zona), ou nil se faltar zona.
    def pick(prompt)
      zones = free(prompt)
      zones.first(prompt[:count]).flatten.pack("C*") if zones.size >= prompt[:count]
    end

    # As zonas que valem, dos dois lados, do centro para as pontas: [jogador, local, sequência].
    # No "flag", bit ligado é zona que não vale (Duel::MessageParser, select_place).
    def free(prompt)
      player = prompt[:player]
      [ player, 1 - player ].each_with_index.flat_map do |owner, side|
        ZONES.flat_map do |location, first_bit, order|
          order.filter_map { |sequence| [ owner, location, sequence ] if prompt[:flag][first_bit + sequence + (16 * side)].zero? }
        end
      end
    end
  end
end
