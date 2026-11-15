module Shop
  # Se o pacote está na prateleira para o jogador e, se não, a dica de como liberar (escopo
  # 3.4; backend/db/seeds/jogo/disponibilidade.yml). Missões, desafios e códigos ainda não
  # existem (GXP-88): esses pacotes ficam bloqueados, com a dica.
  class Availability
    DAYS = %w[domingo segunda terca quarta quinta sexta sabado].freeze
    ON_DAY = { "domingo" => "num domingo", "segunda" => "numa segunda", "terca" => "numa terça", "quarta" => "numa quarta",
               "quinta" => "numa quinta", "sexta" => "numa sexta", "sabado" => "num sábado" }.freeze

    # O que o jogador tem hoje: nível, dia da semana (no fuso do Brasil) e quanto da coleção.
    def self.for(user)
      progress = Collections::Progress.new(user)
      names = Pack.pluck(:id, :name).to_h
      new(level: user.level, day: DAYS[Time.current.wday], total: progress.total,
          packs: progress.packs.to_h { |pack| [ names.fetch(pack[:id]), pack ] })
    end

    # total e packs: { owned:, cards: } (os pacotes pelo nome).
    def initialize(level:, day:, total:, packs:)
      @level = level
      @day = day
      @total = total
      @packs = packs
    end

    # { available:, hint: } para a regra de um pacote (a coluna availability).
    def call(rule)
      parts = rules(rule).map { |each| check(each) }
      available = parts.any? { |part| part[:available] }
      { available:, hint: (hint(parts) unless available) }
    end

    private

    def rules(rule) = rule["regra"] == "qualquer" ? rule["regras"] : [ rule ]

    # Cada regra: se vale agora e o pedaço da dica.
    def check(rule)
      case rule["regra"]
      when "sempre" then { available: true }
      when "dia"
        { available: rule["dia"] == @day || @level >= rule["nivel_libera"],
          hint: "volte #{ON_DAY.fetch(rule['dia'])} ou chegue ao nível #{rule['nivel_libera']}" }
      when "nivel" then { available: @level >= rule["nivel"], hint: "chegue ao nível #{rule['nivel']}" }
      when "porcentagem_de_pacote" then percent(@packs.fetch(rule["pacote"]), rule["porcentagem"], "das cartas de #{rule['pacote']}")
      when "porcentagem_do_total" then percent(@total, rule["porcentagem"], "de todas as cartas do jogo")
      when "todos_os_desafios" then { available: false, hint: "conclua todos os desafios (em breve)" }
      when "codigo" then { available: false, hint: "digite o código secreto na loja (em breve)" }
      else { available: false, hint: "conclua uma missão (em breve)" }
      end
    end

    def percent(progress, needed, what)
      { available: progress[:owned] * 100 >= progress[:cards] * needed,
        hint: "tenha #{needed}% #{what} (você tem #{(progress[:owned] * 100 / [ progress[:cards], 1 ].max)}%)" }
    end

    def hint(parts)
      "#{parts.pluck(:hint).join(', ou ')}.".upcase_first
    end
  end
end
