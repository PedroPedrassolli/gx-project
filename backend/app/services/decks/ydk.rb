module Decks
  # Formato .ydk do YGOPro e do EDOPro (ADR 0009): um código por cópia, nas seções #main,
  # #extra e !side. Não tem Destiny. Carta do anime vai com o código do script da engine.
  module Ydk
    HEADERS = { "#main" => "main", "#extra" => "extra", "!side" => "side" }.freeze

    module_function

    # [{ section:, code:, quantity: }], na ordem em que as cartas aparecem no arquivo.
    def parse(text)
      section = "main"
      copies = Hash.new(0)
      text.each_line do |line|
        line = line.strip
        section = HEADERS[line] if HEADERS.key?(line)
        copies[[ section, line.to_i ]] += 1 if line.match?(/\A\d+\z/)
      end
      copies.map { |(section, code), quantity| { section:, code:, quantity: } }
    end

    def dump(rows)
      lines = [ "#created by GX Project" ]
      HEADERS.each do |header, section|
        lines << header
        rows.select { |row| row[:section] == section }.each { |row| lines.concat([ row[:code] ] * row[:quantity]) }
      end
      lines.join("\n") + "\n"
    end
  end
end
