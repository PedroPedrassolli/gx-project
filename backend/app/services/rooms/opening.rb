module Rooms
  # Quem começa o duelo (escopo 3.7; ADR 0010 item 9). Com a sala cheia e todos prontos, cada
  # um escolhe pedra, papel ou tesoura sem ver a mão do outro; empate repete, e quem ganha
  # escolhe ir primeiro ou segundo. Só aí a partida começa (Matches::Start).
  class Opening
    # Cada mão e a que ela vence.
    BEATS = { "rock" => "scissors", "paper" => "rock", "scissors" => "paper" }.freeze

    # A escolha fora de hora ou de quem não pode fazer.
    class Invalid < StandardError; end

    def initialize(room)
      @room = room
    end

    # A sala está na escolha: esperando o duelo, cheia e com todos prontos.
    def active?
      players = @room.players
      @room.waiting? && players.size == @room.seats && players.all?(&:ready)
    end

    # A mão de um lugar. Quando todos escolheram, a rodada fica à vista: empate começa outra;
    # senão, quem ganhou passa a escolher quem começa.
    def hand!(seat, hand)
      locked do
        raise Invalid, "Agora não é hora de escolher a mão." unless active? && @room.chooser_seat.nil?
        raise Invalid, "Escolha pedra, papel ou tesoura." unless BEATS.key?(hand)
        raise Invalid, "Você já escolheu nesta rodada." if @room.hands.key?(seat.to_s)

        hands = @room.hands.merge(seat.to_s => hand)
        if hands.size < @room.seats
          @room.update!(hands:)
        else
          @room.update!(hands: {}, last_hands: hands, chooser_seat: winner(hands))
        end
      end
    end

    # Quem ganhou escolhe: true, começa; false, o outro começa. Devolve a partida, ou nil se um
    # deck deixou de valer (o dono dele deixa de estar pronto e a escolha recomeça).
    def first!(seat, first)
      locked do
        raise Invalid, "Quem escolhe quem começa é quem ganhou." unless active? && @room.chooser_seat == seat

        first_seat = first ? seat : @room.players.map(&:seat).find { |other| other != seat }
        Matches::Start.new(@room, first_seat:).call.tap { |match| reset! unless match }
      end
    end

    # Alguém saiu, foi tirado ou deixou de estar pronto: a escolha recomeça do zero.
    def reset!
      locked { @room.update!(hands: {}, last_hands: nil, chooser_seat: nil) if @room.hands.any? || @room.last_hands }
    end

    # O que um lugar vê: a própria mão na rodada, quem já escolheu, a rodada anterior e quem
    # escolhe quem começa. A mão do outro só aparece quando todos já escolheram.
    def view(seat)
      return unless active?

      { hand: @room.hands[seat.to_s], chosen: @room.hands.keys.map(&:to_i).sort,
        last: @room.last_hands&.transform_keys(&:to_i), chooser_seat: @room.chooser_seat }
    end

    private

    # A sala travada e lida de novo, com os jogadores: duas escolhas ao mesmo tempo esperam
    # uma pela outra e não se apagam.
    def locked(&)
      @room.with_lock do
        @room.players.reload
        yield
      end
    end

    # O lugar da mão que vence; empate, nil.
    def winner(hands)
      (seat, hand), (other, other_hand) = hands.to_a
      return if hand == other_hand

      (BEATS[hand] == other_hand ? seat : other).to_i
    end
  end
end
