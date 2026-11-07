module Duel
  # Jogador automático e previsível, só para testes e medições: escolhe sempre a primeira
  # opção válida, com algumas preferências para o duelo andar (invocar, baixar cartas,
  # atacar). Os limites por turno evitam laço infinito.
  class TestBot
    LIMIT_PER_TURN = 3

    # destiny: a resposta à pergunta do Destiny Draw.
    def initialize(destiny: true)
      @destiny = destiny
      reset_turn
    end

    def observe(message)
      reset_turn if message.type == MessageParser::NEW_TURN
    end

    def answer(prompt)
      send(prompt[:type], prompt)
    end

    private

    def reset_turn
      @used = Hash.new(0)
    end

    def allowed?(kind)
      return false if @used[kind] >= LIMIT_PER_TURN

      @used[kind] += 1
    end

    def int(value) = [ value ].pack("l<")
    # Comandos de idle/batalha: (índice << 16) | tipo.
    def command(type, index = 0) = int((index << 16) | type)
    # Seleção de cartas: tipo 0 (índices de 32 bits), quantidade e os índices.
    def cards(indexes) = [ 0, indexes.size, *indexes ].pack("l<L<L<*")

    def select_idlecmd(prompt)
      return command(0) if prompt[:summonable].any?
      return command(5) if prompt[:activatable].any? && allowed?(:activate)
      return command(4) if prompt[:ssetable].any? && allowed?(:set)
      return command(6) if prompt[:to_bp]

      command(7)
    end

    def select_battlecmd(prompt)
      return command(1) if prompt[:attackable].any? && allowed?(:attack)
      return command(3) if prompt[:to_ep]

      command(2)
    end

    def select_chain(prompt)
      return int(0) if prompt[:forced] || (prompt[:chains].any? && allowed?(:chain))

      int(-1)
    end

    def select_card(prompt)
      count = prompt[:min].zero? ? [ 1, prompt[:max] ].min : prompt[:min]
      cards((0...count).to_a)
    end

    def select_tribute(prompt) = cards((0...prompt[:min]).to_a)

    # Resposta: quantidade (sempre 1) e o índice; -1 encerra a seleção.
    def select_unselect_card(prompt)
      return int(-1) if prompt[:finishable] || prompt[:selectable].empty?

      [ 1, 0 ].pack("l<l<")
    end

    def select_effectyn(_prompt) = int(1)
    def select_yesno(prompt)
      return int(@destiny ? 1 : 0) if prompt[:description] == Engine::DESTINY_DRAW_QUESTION

      int(1)
    end

    def select_option(_prompt) = int(0)
    def rock_paper_scissors(_prompt) = int(1)
    def announce_number(_prompt) = int(0)
    def sort_card(_prompt) = [ -1 ].pack("c")
    def sort_chain(prompt) = sort_card(prompt)
    def select_position(prompt) = int([ 1, 2, 4, 8 ].find { |bit| prompt[:positions].anybits?(bit) })

    # Primeiras zonas livres. No "flag", bit ligado = zona indisponível:
    # 0-6 monstros do jogador, 8-15 magias/armadilhas, +16 para o oponente.
    def select_place(prompt)
      me = prompt[:player]
      zones = [ [ me, 0x04, 0..6, 0 ], [ me, 0x08, 0..7, 8 ], [ 1 - me, 0x04, 0..6, 16 ], [ 1 - me, 0x08, 0..7, 24 ] ]
      free = zones.flat_map do |player, location, sequences, shift|
        sequences.reject { |sequence| prompt[:flag][sequence + shift] == 1 }.map { |sequence| [ player, location, sequence ] }
      end
      free.first(prompt[:count]).flatten.pack("C*")
    end

    def select_disfield(prompt) = select_place(prompt)

    def select_counter(prompt)
      left = prompt[:count]
      prompt[:cards].map { |card| card[:counters].clamp(0, left).tap { |taken| left -= taken } }.pack("s<*")
    end

    def announce_race(prompt) = [ lowest_bits(prompt[:available], prompt[:count]) ].pack("Q<")
    def announce_attrib(prompt) = [ lowest_bits(prompt[:available], prompt[:count]) ].pack("L<")

    def lowest_bits(mask, count)
      (0...64).select { |bit| mask[bit] == 1 }.first(count).sum { |bit| 1 << bit }
    end
  end
end
