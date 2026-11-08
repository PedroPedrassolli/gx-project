module GameData
  # Texto da época das cartas que a engine joga pela regra antiga (pré-errata): a versão em
  # inglês que valia quando o jogo saiu, pela página "Card Errata:" da Yugipedia. Cada
  # versão vale desde o primeiro pacote que a imprimiu.
  class EraText
    SET_CODE = /\A[A-Z0-9]+-[A-Z]*\d+\z/ # "MRD-069" é o código da carta, não o pacote

    # released_on: data em que o jogo saiu (a primeira em inglês, da página do jogo).
    def initialize(client, released_on)
      @client, @released_on = client, released_on
    end

    # { "Sangan" => { texto: "...", fonte: revisão da página de errata } }
    def texts(names)
      pages = @client.pages_by_title(names.map { |name| "Card Errata:#{name}" })
      versions = names.filter_map { |name| (page = pages["Card Errata:#{name}"]) && [ name, page ] }
                      .to_h { |name, page| [ name, [ page, Wikitext.errata_versions(page.text) ] ] }
      dates = set_dates(versions.values.flat_map { |_page, list| list.filter_map { |version| first_set(version) } })
      versions.filter_map do |name, (page, list)|
        chosen = pick(list, dates)
        [ name, { texto: chosen[:texto], fonte: page.revision } ] if chosen
      end.to_h
    end

    private

    # A última versão impressa até o jogo sair; se nenhuma tem data até lá, a primeira (a
    # impressão original). Mudança só de número ("DEF/3800") não é texto e não conta.
    def pick(list, dates)
      texts = list.select { |version| version[:texto].to_s.scan(/[A-Za-z]+/).size >= 3 }
      printed = texts.select { |version| (date = printed_on(version, dates)) && date <= @released_on }
      printed.last || texts.first
    end

    # Data do primeiro pacote da legenda; sem pacote, a data escrita na própria legenda
    # (lista de errata em PDF, página arquivada).
    def printed_on(version, dates)
      set = first_set(version)
      set ? dates[set] : Wikitext.date(version[:legenda])
    end

    def first_set(version) = Wikitext.links(version[:legenda]).find { |title| !title.match?(SET_CODE) }

    def set_dates(titles)
      @client.pages_by_title(titles.uniq, section: 0).transform_values { |page| Wikitext.release_date(page.text) }
    end
  end
end
