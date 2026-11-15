module Matches
  # O duelo de uma partida na engine (ADR 0011): a Duel::Session com a semente, os decks e as
  # respostas do banco. Guarda na partida o turno, a fase e a pergunta da vez, e responde
  # sozinho o que não precisa de jogador: a cadeia sem opção (escopo 3.7: só pergunta quem
  # pode responder) e a zona da carta que vai para o campo (Matches::AutoPlace).
  class Game
    # "Não encadear" (-1), a resposta da cadeia sem opção.
    PASS = [ -1 ].pack("l<")

    def initialize(match)
      @match = match
      decks = match.players.map { |player| player.deck.deep_symbolize_keys }
      @session = Duel::Session.new(id: "match-#{match.id}", seed: match.seed, decks:,
                                   responses: match.responses.map(&:bytes), destiny_draw: match.destiny_draw)
    end

    # A vez é de outro time, ou o duelo acabou.
    class NotYourTurn < StandardError; end

    # Primeira vez: a engine roda até a primeira pergunta de verdade.
    def start!
      settle(@session.start)
    end

    # A escolha do time para a pergunta da vez (o JSON da tela). A forma errada sobe
    # Duel::ResponseEncoder::InvalidChoice; a jogada que a engine recusa sobe
    # Duel::Session::InvalidResponse. Nos dois casos, nada muda.
    def respond!(team, choice)
      raise NotYourTurn, "Não é a sua vez." unless @match.dueling? && @match.prompt_team == team

      settle(answer(team, Duel::ResponseEncoder.encode(@match.prompt["type"], choice)))
    end

    # A mesa vista por um time (Duel::View), com o que a partida guardou.
    def view(team)
      state = @match.slice(:turn, :turn_team, :phase, :prompt_team).symbolize_keys
      @session.with_engine { |engine| Duel::View.new(engine, team).to_h(**state, prompt: @match.prompt&.deep_symbolize_keys) }
    end

    private

    def settle(messages)
      loop do
        prompt = record(messages)
        bytes = automatic(prompt)
        break unless bytes

        messages = answer(prompt[:player], bytes)
      end
      @match.save!
    end

    def answer(team, bytes)
      messages = @session.respond(bytes)
      @match.responses.build(seq: @session.responses.size - 1, team:, bytes:)
      messages
    end

    def record(messages)
      messages.each do |message|
        case message.type
        when Duel::MessageParser::NEW_TURN then new_turn(message)
        when Duel::MessageParser::NEW_PHASE then @match.phase = message.payload.unpack1("S<")
        when Duel::MessageParser::WIN then finish(Duel::MessageParser.win(message))
        end
      end
      # A coluna jsonb guarda as chaves como texto: a pergunta que volta daqui fica com símbolos.
      prompt = Duel::MessageParser.prompt(messages.last) unless @session.finished?
      @match.prompt = prompt
      @match.prompt_team = prompt&.fetch(:player)
      prompt
    end

    # O turno conta a partir de 1; o primeiro byte diz de quem é a vez.
    def new_turn(message)
      @match.turn += 1
      @match.turn_team = message.payload.getbyte(0)
    end

    # A resposta que o servidor dá sozinho, ou nil quando a pergunta é do jogador.
    def automatic(prompt)
      case prompt&.fetch(:type)
      when :select_chain then PASS if prompt[:chains].empty? && !prompt[:forced]
      when :select_place then AutoPlace.pick(prompt)
      end
    end

    # 2 é empate: ninguém vence.
    def finish(win)
      @match.assign_attributes(status: "finished", winner_team: (win[:player] unless win[:player] == 2), finished_at: Time.current)
    end
  end
end
