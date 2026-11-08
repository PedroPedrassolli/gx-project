module Decks
  # Cria um deck a partir de um arquivo .ydk ou de texto (ADR 0009). Não falha por pouco:
  # carta fora do pool fica de fora e mais de 3 cópias viram 3, com um aviso para cada
  # coisa. Só não cria o deck quando nada do arquivo está no pool.
  class Import
    KINDS = %w[ydk text].freeze
    # Um .ydk de deck cheio tem uns 1,5 KB; em texto, uns 4 KB.
    MAX_BYTES = 50_000
    DEFAULT_NAME = "Deck importado".freeze

    attr_reader :deck, :warnings, :error

    # params: nome, formato (kind: "ydk" ou "text") e o conteúdo do arquivo.
    def initialize(user, params)
      @deck = user.decks.build
      @name = params[:name].presence || DEFAULT_NAME
      @kind = params[:kind]
      @content = params[:content].to_s
      @warnings = []
    end

    # true quando cria o deck. Senão, o motivo fica em error, ou os erros do deck em deck.errors.
    def save
      return fail_with("Formato desconhecido: use ydk ou text.") unless KINDS.include?(@kind)
      return fail_with("Arquivo grande demais: o limite é 50 KB.") if @content.bytesize > MAX_BYTES

      rows = Editor.merge(@kind == "ydk" ? ydk_rows : text_rows).map { |row| at_most_three(row) }
      return fail_with("Nenhuma carta do arquivo está no pool.") if rows.empty?

      Editor.new(deck).save(name: @name, cards: rows)
    end

    private

    def fail_with(message)
      @error = message
      false
    end

    # Código do arquivo: o passcode, ou o código da engine para carta do anime.
    def ydk_rows
      rows = Ydk.parse(@content)
      codes = rows.pluck(:code)
      cards = Card.where(engine_code: codes).index_by(&:engine_code).merge(Card.where(passcode: codes).index_by(&:passcode))
      rows.filter_map do |row|
        card = cards[row[:code]]
        next skip("O código #{row[:code]} não está no pool.") unless card

        { card_id: card.id, section: row[:section], quantity: row[:quantity], destiny: false }
      end
    end

    # Nome em inglês ou em português, sem diferenciar maiúsculas.
    def text_rows
      result = Text.parse(@content)
      @warnings.concat(result.errors)
      names = result.rows.map { |row| row[:name].downcase }
      cards = Card.where("lower(name) IN (:names) OR lower(name_pt) IN (:names)", names:)
      by_name = cards.index_by { |card| card.name.downcase }.merge(cards.select(&:name_pt).index_by { |card| card.name_pt.downcase }) { |_, english, _| english }
      result.rows.filter_map do |row|
        card = by_name[row[:name].downcase]
        next skip("\"#{row[:name]}\" não está no pool.") unless card

        { card_id: card.id, section: row[:section], quantity: row[:quantity], destiny: row[:destiny] }
      end
    end

    # Avisa da carta que ficou de fora; devolve nil para o filter_map pular a linha.
    def skip(warning)
      @warnings << warning
      nil
    end

    def at_most_three(row)
      return row if row[:quantity] <= 3

      @warnings << "#{Card.find(row[:card_id]).name}: o arquivo tinha #{row[:quantity]} cópias; ficaram 3."
      row.merge(quantity: 3)
    end
  end
end
