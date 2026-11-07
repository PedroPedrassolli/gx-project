module GameData
  # Tira os dados do texto das páginas da Yugipedia (formato wiki). São só funções que
  # recebem texto e devolvem listas e hashes: nada de rede aqui.
  module Wikitext
    module_function

    # Valor de um campo de infobox: "| size = 68" → "68". Campo vazio vira nil.
    def field(text, name)
      value = text[/^\|\s*#{Regexp.escape(name)}\s*=[ \t]*(.*)$/, 1]
      value&.strip.presence
    end

    # Texto de uma seção "== Nome ==", até a próxima seção do mesmo nível ou acima.
    def section(text, name)
      text[/^==\s*#{Regexp.escape(name)}\s*==\s*$(.*?)(?=^==[^=]|\z)/m, 1].to_s
    end

    # Linhas do {{Video game set list}}: "Título; Raridade; Quantidade". A raridade e a
    # quantidade podem faltar. Linha sem título (como "; 1") é ignorada.
    def set_list(text)
      body = text[/\{\{Video game set list.*?\|\s*cards\s*=(.*?)\}\}/m, 1].to_s
      body.lines.filter_map do |line|
        title, rarity, quantity = line.split(";").map(&:strip)
        next if title.blank?

        { title:, rarity: rarity.presence, quantity: (quantity.presence || 1).to_i }
      end
    end

    # Título de página sem o último qualificador: "Ancient Gear (card) (X)" → "Ancient Gear (card)".
    def base_title(title)
      title.sub(/\s*\([^()]*\)\s*\z/, "")
    end

    # Nome da carta, sem nenhum qualificador: "Ancient Gear (card) (X)" → "Ancient Gear".
    def card_name(title)
      title.sub(/(\s*\([^()]*\))+\s*\z/, "")
    end

    # "Each pack costs 1,000 DP and contains 5 cards." → { price: 1000, cards: 5 }
    def pack_price(text)
      match = text.match(/costs ([\d,]+) DP and contains (\d+) cards/)
      match && { price: match[1].delete(",").to_i, cards: match[2].to_i }
    end

    # Grupos do {{Card converter list}}: "; 10" abre o grupo e cada ": Título" entra nele.
    def converter_groups(text)
      groups = Hash.new { |hash, amount| hash[amount] = [] }
      amount = nil
      text.each_line do |line|
        if (opened = line[/^;\s*(\d+)\s*$/, 1])
          amount = opened.to_i
        elsif amount && (title = line[/^:\s*(.+?)\s*$/, 1])
          groups[amount] << title
        end
      end
      groups
    end

    # Itens "* 001. Texto" de uma seção.
    def numbered_items(text, section_name)
      section(text, section_name).scan(/^\*\s*(\d+)\.\s*(.+?)\s*$/).map do |number, item|
        { number: number.to_i, text: item }
      end
    end

    # Linhas do {{Limitation status list}}: "Título; Forbidden".
    def limitation_list(text)
      body = text[/\{\{Limitation status list.*?\|\s*cards\s*=(.*?)\}\}/m, 1].to_s
      body.lines.filter_map do |line|
        title, status = line.split(";").map(&:strip)
        { title:, status: } if title.present? && status.present?
      end
    end

    # Títulos dos links no começo de cada item "* [[Título|Nome]] - data" de uma seção.
    def linked_items(text, section_name)
      section(text, section_name).scan(/^\*\s*\[\[([^\]|]+)/).flatten.map(&:strip)
    end

    # Títulos de todos os links "[[Título|Texto]]".
    def links(text)
      text.scan(/\[\[([^\]|]+)/).flatten.map(&:strip)
    end

    # Itens de uma {{Decklist}} marcados com o link do Destiny Draw ("(D)").
    def destiny_cards(text)
      text.scan(/^\*\s*\[\[([^\]|]+)[^\n]*\|D\]\]/).flatten.map(&:strip)
    end
  end
end
