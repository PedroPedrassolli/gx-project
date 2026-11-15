module Matches
  # O duelo de uma partida na engine (ADR 0011): a Duel::Session com a semente, os decks e as
  # respostas do banco. Guarda na partida o turno, a fase e a pergunta da vez, e responde
  # sozinho o que não precisa de jogador: a cadeia sem opção (escopo 3.7: só pergunta quem
  # pode responder) e a zona da carta que vai para o campo (Matches::AutoPlace).
  class Game
    # "Não encadear" (-1), a resposta da cadeia sem opção.
    PASS = [ -1 ].pack("l<")
    # Quantos eventos a partida guarda para o log da mesa (GXP-65).
    MAX_EVENTS = 50

    # cache: onde ficam as engines vivas; o replay passa um só dele (Matches::Replay).
    def initialize(match, cache: Duel::Session::CACHE)
      @match = match
      decks = match.players.map { |player| player.deck.deep_symbolize_keys }
      @session = Duel::Session.new(id: "match-#{match.id}", seed: match.seed, decks:, cache:,
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

      spend_turn_time(team)
      settle(answer(team, Duel::ResponseEncoder.encode(@match.prompt["type"], choice)))
    end

    # O prazo da pergunta venceu ou o duelo passou do limite.
    def expired?(now = Time.current)
      @match.dueling? && ((@match.deadline_at && now > @match.deadline_at) || (@match.ends_at && now > @match.ends_at))
    end

    # Prazo vencido: quem devia responder perde. Passou do limite do duelo: ganha quem tem
    # mais PV (iguais, empate). Devolve se a partida acabou agora.
    def expire!(now = Time.current)
      return false unless expired?(now)

      if @match.deadline_at && now > @match.deadline_at
        close(winner: 1 - @match.prompt_team, reason: "timeout")
      else
        lp = @session.with_engine { |engine| engine.query_field.map { |side| side[:lp] } }
        close(winner: (lp.index(lp.max) unless lp.uniq.size == 1), reason: "time_limit")
      end
      true
    end

    def surrender!(team)
      raise NotYourTurn, "O duelo já acabou." unless @match.dueling?

      close(winner: 1 - team, reason: "surrender")
    end

    # Replay (Matches::Replay): refaz o duelo do começo com as respostas guardadas, numa
    # partida que não vai para o banco, e devolve a mesa do time depois de cada resposta do
    # turno pedido que mudou algo, com os eventos dela. Para no fim do turno.
    def replay(team, responses, turn)
      frames = []
      going = replay_step(@session.start, team, turn, frames, 0)
      responses.each_with_index do |bytes, index|
        break unless going

        going = replay_step(@session.respond(bytes), team, turn, frames, index + 1)
      end
      frames
    end

    # A mesa vista por um time (Duel::View), com o que a partida guardou.
    def view(team)
      state = @match.slice(:turn, :turn_team, :phase, :prompt_team).symbolize_keys
      state.merge!(prompt: @match.prompt&.deep_symbolize_keys, events: events, chain: chain)
      @session.with_engine { |engine| Duel::View.new(engine, team).to_h(**state) }
    end

    private

    def settle(messages)
      loop do
        prompt = record(messages)
        bytes = automatic(prompt)
        break unless bytes

        messages = answer(prompt[:player], bytes)
      end
      start_clock if @match.dueling?
      @match.save!
      reopen_room unless @match.dueling?
    end

    # A pergunta nova abre agora: o prazo é o da decisão ou o que sobra do banco do turno.
    def start_clock
      now = Time.current
      @match.prompt_at = now
      @match.deadline_at = Clock.deadline(now, turn_player: @match.prompt_team == @match.turn_team, bank: @match.turn_time_left,
                                                decision: @match.decision_seconds)
    end

    # O jogador da vez gasta do banco do turno o tempo que levou para responder.
    def spend_turn_time(team)
      return unless team == @match.turn_team && @match.prompt_at

      @match.turn_time_left = [ @match.turn_time_left - (Time.current - @match.prompt_at).to_i, 0 ].max
    end

    # Fim fora do duelo (prazo, limite, desistência): grava e reabre a sala.
    def close(winner:, reason:)
      @match.update!(status: "finished", winner_team: winner, finish_reason: reason, finished_at: Time.current,
                     prompt: nil, prompt_team: nil, deadline_at: nil)
      reopen_room
    end

    # A partida acabou: a sala volta a esperar, com todos "não pronto", para a revanche.
    def reopen_room
      room = @match.room
      return unless room&.status == "dueling"

      room.update!(status: "waiting")
      room.players.update_all(ready: false)
    end

    def answer(team, bytes)
      messages = @session.respond(bytes)
      @match.responses.build(seq: @session.responses.size - 1, team:, bytes:)
      messages
    end

    def record(messages)
      log(Duel::Events.from(messages))
      messages.each do |message|
        case message.type
        when Duel::MessageParser::NEW_TURN then new_turn(message)
        when Duel::MessageParser::NEW_PHASE then @match.phase = message.payload.unpack1("S<")
        when Duel::MessageParser::WIN then finish(Duel::MessageParser.win(message))
        end
      end
      # A coluna jsonb guarda as chaves como texto: a pergunta que volta daqui fica com símbolos.
      prompt = Duel::MessageParser.prompt(messages.last) unless @session.finished?
      hint = Duel::MessageParser.select_hint(messages, prompt) if prompt
      prompt = prompt.merge(hint:) if hint
      @match.prompt = prompt
      @match.prompt_team = prompt&.fetch(:player)
      prompt
    end

    # Registra as mensagens de uma resposta e guarda o quadro quando ela é do turno pedido.
    # Falso quando o duelo já passou do turno: o resto não precisa ser refeito.
    def replay_step(messages, team, turn, frames, step)
      before = @match.events_count
      record(messages)
      return false if @match.turn > turn

      frames << frame(team, step, @match.events_count - before) if @match.turn == turn && @match.events_count > before
      true
    end

    # Um quadro do replay: a mesa depois da resposta, sem pergunta, com os eventos novos.
    def frame(team, step, count)
      state = @match.slice(:turn, :turn_team, :phase).symbolize_keys
      view = @session.with_engine do |engine|
        Duel::View.new(engine, team).to_h(**state, prompt: nil, prompt_team: nil, events: events.last(count), chain:)
      end
      { step:, view: }
    end

    # O jsonb do banco volta com as chaves em texto; aqui elas ficam com símbolos.
    def events = @match.events.map(&:deep_symbolize_keys)
    def chain = @match.chain.map(&:deep_symbolize_keys)

    # Os últimos eventos, numerados, para o log da mesa, e a corrente aberta (Duel::Events).
    def log(new_events)
      return if new_events.empty?

      first = @match.events_count
      numbered = new_events.each_with_index.map { |event, index| with_codes(event).merge(id: first + index + 1) }
      @match.assign_attributes(events: (events + numbered).last(MAX_EVENTS), events_count: first + new_events.size,
                               chain: new_events.reduce(chain) { |links, event| follow_chain(links, event) })
    end

    # A mensagem do ataque só tem a posição das cartas. O código sai da mesa na hora, que
    # ainda é de antes da batalha, e só das cartas com a face para cima (as que todos veem).
    def with_codes(event)
      return event unless event[:type] == "attack"

      @session.with_engine do |engine|
        event.merge(attacker: face_up_code(engine, event[:attacker]), target: (face_up_code(engine, event[:target]) if event[:target]))
      end
    end

    # A carta como está no fim da jogada: virada para cima, com o código e a posição de agora
    # (a batalha pode ter virado o alvo na mesma jogada); virada para baixo, sem código.
    def face_up_code(engine, place)
      card = engine.query_location(place[:controller], Duel::Query::MONSTERS)[place[:sequence]]
      card && card[:position].anybits?(Duel::Events::FACE_UP) ? place.merge(card.slice(:code, :position)) : place
    end

    # O elo entra na ativação, fica marcado quando é negado e sai quando resolve.
    def follow_chain(links, event)
      case event[:type]
      when "chain" then links + [ event.slice(:code, :controller, :location, :sequence, :position, :description, :link) ]
      when "chain_negated" then links.map { |link| link[:link] == event[:link] ? link.merge(negated: true) : link }
      when "chain_solved" then links.reject { |link| link[:link] == event[:link] }
      when "chain_end" then []
      else links
      end
    end

    # O turno conta a partir de 1; o primeiro byte diz de quem é a vez.
    def new_turn(message)
      @match.turn += 1
      @match.turn_team = message.payload.getbyte(0)
      @match.turn_time_left = Clock.turn_bank(@match.decision_seconds)
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
      @match.assign_attributes(status: "finished", winner_team: (win[:player] unless win[:player] == 2), finish_reason: "duel",
                               finished_at: Time.current, deadline_at: nil)
    end
  end
end
