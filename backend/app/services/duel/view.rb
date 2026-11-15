module Duel
  # A mesa vista por um lado (escopo 3.7: "cada jogador recebe só o que pode ver"). Lê a
  # engine pelas consultas (Duel::Query) e esconde o que é do outro e não está à vista: a
  # mão, o Extra e as cartas viradas para baixo. Do deck, os dois só sabem quantas cartas há.
  class View
    # Posições (POS_* do ocgapi_constants.h).
    FACE_DOWN = 0x2 | 0x8
    DEFENSE = 0x4 | 0x8
    PHASES = { 0x01 => "draw", 0x02 => "standby", 0x04 => "main1", 0x100 => "main2", 0x200 => "end" }.freeze
    BATTLE = 0x08 | 0x10 | 0x20 | 0x40 | 0x80
    # Listas de cartas dentro das perguntas, que podem trazer carta escondida do outro.
    PROMPT_LISTS = %i[summonable spsummonable repositionable msetable ssetable activatable attackable
                      cards selectable unselectable chains].freeze

    def initialize(engine, viewer)
      @engine = engine
      @viewer = viewer
    end

    # A mesa inteira. A pergunta só vai para quem responde; o outro vê de quem é a vez.
    def to_h(turn:, turn_team:, phase:, prompt:, prompt_team:)
      { you: @viewer, turn:, turn_team:, phase: phase_name(phase), sides:, waiting_for: prompt_team,
        prompt: (mask(prompt) if prompt && prompt_team == @viewer) }.compact
    end

    def sides
      field = @engine.query_field
      [ 0, 1 ].map { |team| side(team, field[team]) }
    end

    private

    def phase_name(phase) = phase.anybits?(BATTLE) ? "battle" : PHASES[phase]

    def side(team, counts)
      mine = team == @viewer
      spells = @engine.query_location(team, Query::SPELLS)
      {
        team:, lp: counts[:lp], deck: counts[:deck], extra: counts[:extra],
        hand: @engine.query_location(team, Query::HAND).map { |card| mine || card[:public] ? { code: card[:code] } : { hidden: true } },
        monsters: @engine.query_location(team, Query::MONSTERS).first(5).map { |card| field_card(card, mine) },
        spells: spells.first(5).map { |card| field_card(card, mine) },
        field_spell: field_card(spells[5], mine),
        grave: @engine.query_location(team, Query::GRAVE).map { |card| { code: card[:code] } },
        banished: @engine.query_location(team, Query::BANISHED).map { |card| card[:public] || mine ? { code: card[:code] } : { hidden: true } },
        extra_cards: (@engine.query_location(team, Query::EXTRA).map { |card| { code: card[:code] } } if mine)
      }.compact
    end

    # Carta no campo: virada para baixo e do outro, só a posição (ataque ou defesa).
    def field_card(card, mine)
      return if card.nil?

      face_down = card[:position].anybits?(FACE_DOWN)
      shown = { face_down:, defense: card[:position].anybits?(DEFENSE) }
      return shown if face_down && !mine

      shown.merge(code: card[:code], atk: card[:atk], def: card[:def])
    end

    # Esconde o código das cartas que o jogador não vê e põe o texto de cada descrição.
    def mask(prompt)
      shown = prompt.to_h do |key, value|
        [ key, PROMPT_LISTS.include?(key) ? value.map { |card| with_text(hidden?(card) ? card.merge(code: 0) : card) } : value ]
      end
      shown[:options_text] = shown[:options].map { |option| text(option) } if shown[:options]
      with_text(shown)
    end

    def with_text(item)
      item[:description] ? item.merge(text: text(item[:description])) : item
    end

    # A descrição é (código da carta << 20) | número do texto (aux.Stringid). Sem carta, é um
    # texto do próprio jogo: aqui só o do Destiny Draw, o resto a tela descreve.
    def text(description)
      return "Usar o Destiny Draw?" if description == Engine::DESTINY_DRAW_QUESTION

      code = description >> 20
      Engine.cards.strings(code)[description & 0xFFFFF].presence if code.positive?
    end

    # Carta do outro na mão, no deck, no Extra ou virada no campo: o código não vai.
    def hidden?(card)
      return false if card[:controller] == @viewer
      return true if [ Query::DECK, Query::HAND, Query::EXTRA ].include?(card[:location])

      card[:position].to_i.anybits?(FACE_DOWN)
    end
  end
end
