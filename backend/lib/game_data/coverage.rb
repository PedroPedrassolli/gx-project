module GameData
  # Cruza o pool do jogo de referência com a engine (scripts e BabelCDB) e com as imagens do
  # YGOPRODeck. A regra geral é a carta entrar pelo próprio passcode; o arquivo guarda só as
  # exceções, cada uma com a decisão.
  class Coverage
    NORMAL_MONSTER = 0x10 # TYPE_NORMAL da engine: carta Normal não tem script

    # cards: entradas do cartas.yml; database: linhas do BabelCDB ({ id:, alias:, type:,
    # name:, unofficial: }); scripts: { "official" => Set[ids], "pre-errata" => ...,
    # "unofficial" => ... }; images: Set com os ids que têm imagem.
    def initialize(cards:, database:, scripts:, images:)
      @cards, @scripts, @images = cards, scripts, images
      @by_id = database.index_by { |row| row[:id] }
      @by_name = database.group_by { |row| [ row[:unofficial], row[:name].downcase ] }
      @pre_errata = database.select { |row| row[:alias].positive? && script?("pre-errata", row[:id]) }
                            .to_h { |row| [ row[:alias], row[:id] ] }
    end

    # Texto da época das cartas pré-errata, por nome: { "Sangan" => { texto:, fonte: } }.
    attr_writer :era_texts

    def entries
      @entries ||= @cards.map { |card| card["passcode"] ? official(card) : anime(card) }
    end

    def pre_errata_names = entries.select { |entry| entry[:motivo] == "pre_errata" }.pluck(:nome)

    def summary
      { cartas: entries.size, oficiais: entries.count { |entry| entry[:passcode] },
        normais: entries.count { |entry| entry[:motivo] == "normal" },
        pre_errata: count("pre_errata"), anime: count("anime"), usar_oficial: count("usar_oficial"),
        tirar_do_pool: count("tirar_do_pool"), sem_script: count("sem_script"),
        pre_errata_sem_texto: pre_errata_names.count { |name| !era_texts[name] },
        sem_dados: entries.count { |entry| entry[:codigo] && !@by_id[entry[:codigo]] },
        sem_imagem: entries.count { |entry| !entry[:imagem] } }
    end

    def file
      exceptions = entries.reject { |entry| %w[oficial normal].include?(entry[:motivo]) }
      [ "# Pool do jogo × engine (scripts e BabelCDB) × imagens do YGOPRODeck (ADR 0006).",
        "# Regra geral: a carta entra pelo próprio passcode, com o script oficial (carta Normal",
        "# não tem script) e a imagem do YGOPRODeck. Aqui ficam só as exceções:",
        "#   pre_errata: usa o script antigo da carta (o jogo é de 2008) e o texto da época",
        "#     (texto e fonte_texto: a versão da página \"Card Errata:\" que valia quando o jogo saiu);",
        "#   anime: versão do jogo, pelo script não oficial (VG, mesmo nome ou Anime);",
        "#   usar_oficial: carta do anime sem script; usa a carta impressa depois, de mesmo nome;",
        "#   tirar_do_pool: carta do anime sem script nenhum; fica fora até ganhar um script;",
        "#   sem_script: carta oficial sem script na engine.",
        "# Gerado por `bin/rails dados:cobertura`: não edite à mão.",
        "resumo: #{flow(summary)}", "excecoes:", *exceptions.map { |entry| "  - #{flow(with_era_text(entry))}" } ].join("\n") + "\n"
    end

    private

    def era_texts = @era_texts || {}

    def with_era_text(entry)
      text = entry[:motivo] == "pre_errata" && era_texts[entry[:nome]]
      text ? entry.merge(texto: text[:texto], fonte_texto: text[:fonte]) : entry
    end

    def official(card)
      code = card["passcode"]
      reason = if @pre_errata[code] then "pre_errata"
      elsif normal?(code) then "normal"
      elsif script?("official", code) || script?("pre-errata", code) then "oficial"
      else "sem_script"
      end
      entry(card, @pre_errata.fetch(code, code), reason, image: @images.include?(code))
    end

    # Ordem de preferência: a versão de video game (VG), o mesmo nome e a versão do anime.
    def anime(card)
      name = card["nome"]
      row = [ "#{name} (VG)", name, "#{name} (Anime)" ].lazy.filter_map { |candidate| unofficial(candidate) }.first
      return entry(card, row[:id], "anime", image: false, script: row[:name]) if row

      printed = printed_code(card)
      return entry(card, printed, "usar_oficial", image: @images.include?(printed)) if printed

      entry(card, nil, "tirar_do_pool", image: false)
    end

    # A impressão oficial posterior: pelo passcode que a Yugipedia dá ou pelo mesmo nome no
    # BabelCDB.
    def printed_code(card)
      code = card["passcode_oficial"]
      return code if code && script?("official", code)

      @by_name[[ false, card["nome"].downcase ]]&.find { |row| script?("official", row[:id]) }&.fetch(:id)
    end

    def unofficial(name)
      @by_name[[ true, name.downcase ]]&.find { |row| script?("unofficial", row[:id]) }
    end

    def entry(card, code, reason, image:, script: nil)
      { nome: card["nome"], passcode: card["passcode"], numero_interno: card["numero_interno"],
        codigo: code, motivo: reason, script:, imagem: image }
    end

    def normal?(code) = @by_id.dig(code, :type).to_i & NORMAL_MONSTER != 0
    def script?(folder, id) = @scripts.fetch(folder).include?(id)
    def count(reason) = entries.count { |entry| entry[:motivo] == reason }
    def flow(hash) = "{ #{hash.compact.map { |key, value| "#{key}: #{JSON.generate(value)}" }.join(', ')} }"
  end
end
