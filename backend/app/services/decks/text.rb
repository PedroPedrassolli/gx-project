module Decks
  # Formato de texto do GX Project (ADR 0009), fácil de ler e de escrever à mão:
  #
  #   Main Deck
  #   3 Dark Magician
  #   1 D.D. Assailant (Destiny)
  #
  # Seção com ou sem a palavra "Deck" e os dois pontos; quantidade com ou sem "x". Linha
  # em branco ou com "#" é ignorada; carta antes de qualquer seção vai para o Main.
  module Text
    SECTIONS = { "main" => "Main Deck", "extra" => "Extra Deck", "side" => "Side Deck" }.freeze
    SECTION_LINE = /\A(main|extra|side)(\s+deck)?:?\z/i
    CARD_LINE = /\A([1-9]\d*)\s*x?\s+(.+?)(\s+\(destiny\))?\z/i

    # rows: [{ section:, name:, quantity:, destiny: }]; errors: as linhas que não deu para ler.
    Result = Struct.new(:rows, :errors)

    module_function

    def parse(text)
      result = Result.new([], [])
      section = "main"
      text.each_line.with_index(1) do |line, number|
        line = line.strip
        next if line.empty? || line.start_with?("#")

        if (header = SECTION_LINE.match(line))
          section = header[1].downcase
        elsif (card = CARD_LINE.match(line))
          result.rows << { section:, name: card[2], quantity: card[1].to_i, destiny: card[3].present? }
        else
          result.errors << "Linha #{number}: não entendi \"#{line}\"."
        end
      end
      result
    end

    # Só as seções que têm cartas, separadas por uma linha em branco.
    def dump(rows)
      blocks = SECTIONS.filter_map do |section, title|
        lines = rows.select { |row| row[:section] == section }
                    .map { |row| "#{row[:quantity]} #{row[:name]}#{" (Destiny)" if row[:destiny]}" }
        [ title, *lines ].join("\n") if lines.any?
      end
      blocks.join("\n\n") + "\n"
    end
  end
end
