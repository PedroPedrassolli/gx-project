module Catalog
  # Grava no banco o catálogo dos YAML de db/seeds/jogo. Pode rodar quantas vezes quiser:
  # carta, pacote, banlist e grupo do conversor são atualizados pela chave de cada um (o
  # código da engine, o nome e a quantidade), o que saiu dos arquivos é apagado, e as
  # listas (cartas do pacote, da banlist e do grupo) são refeitas. Tudo numa transação.
  class Importer
    RARITIES = { "comum" => "common", "rara" => "rare", "super_rara" => "super_rare",
                 "ultra_rara" => "ultra_rare" }.freeze
    STATUSES = { "proibida" => "forbidden", "limitada" => "limited",
                 "semi_limitada" => "semi_limited" }.freeze
    DEFAULT_BANLIST = "Padrão do jogo".freeze

    def initialize(directory = Rails.root.join("db/seeds/jogo"))
      @directory = Pathname(directory)
    end

    # Devolve quantos registros ficaram em cada tabela.
    def run
      ApplicationRecord.transaction do
        [ PackCard, BanlistEntry, ConverterGroupCard ].each(&:delete_all)
        import_cards
        import_packs
        import_banlist
        import_converter
      end
      { cards: Card.count, packs: Pack.count, pack_cards: PackCard.count,
        banlist_entries: BanlistEntry.count, converter_cards: ConverterGroupCard.count }
    end

    private

    def load(name) = YAML.safe_load_file(@directory.join(name))

    # ---- cartas ----------------------------------------------------------------------

    def import_cards
      rows = cards.filter_map { |card| card_row(card) }.uniq { |row| row[:engine_code] }
      Card.upsert_all(rows, unique_by: :engine_code, record_timestamps: true)
      Card.where.not(engine_code: rows.pluck(:engine_code)).destroy_all
      @card_ids = Card.pluck(:engine_code, :id).to_h
    end

    def cards = @cards ||= load("cartas.yml")

    def card_row(card)
      code = engine_code(card)
      code && { engine_code: code, passcode: card["passcode"], internal_number: card["numero_interno"],
                name: card["nome"], name_in_game: card["nome_no_jogo"], **shown(card) }
    end

    # O que o jogador vê segue a carta que a engine roda: a carta impressa, quando a do anime
    # usa a oficial; o texto da época, quando a carta usa a regra antiga. O texto em
    # português é o atual: se o texto da época é outro, fica só o inglês.
    def shown(card)
      exception = exceptions[card.values_at("nome", "passcode", "numero_interno")]
      data = exception&.dig("motivo") == "usar_oficial" && card["impressao"] || card
      text = exception&.dig("texto") || data["texto"]
      { name_pt: data["nome_pt"], card_type: data["tipo"], property: data["propriedade"],
        card_attribute: data["atributo"], race: data["raca"], monster_types: data["tipos"] || [],
        level: data["nivel"], attack: data["atk"], defense: data["def"], text:,
        text_pt: (data["texto_pt"] if text == data["texto"]), source_revision: data["fonte"] }
    end

    # O código da engine sai da cobertura; carta "tirar_do_pool" fica sem código e não entra.
    def engine_code(card)
      exception = exceptions[card.values_at("nome", "passcode", "numero_interno")]
      return card["passcode"] unless exception

      exception["codigo"] unless exception["motivo"] == "tirar_do_pool"
    end

    def exceptions
      @exceptions ||= load("cobertura.yml")["excecoes"].index_by { |item| item.values_at("nome", "passcode", "numero_interno") }
    end

    # Id da carta citada em outra lista: pelo passcode, pelo número interno ou pelo nome.
    def card_id(reference)
      card = cards_by_passcode[reference["passcode"]] || cards_by_internal[reference["numero_interno"]] ||
             cards_by_name[reference["nome"]]
      code = card && engine_code(card)
      code && @card_ids[code]
    end

    def cards_by_passcode = @cards_by_passcode ||= cards.select { |card| card["passcode"] }.index_by { |card| card["passcode"] }
    def cards_by_internal = @cards_by_internal ||= cards.select { |card| card["numero_interno"] }.index_by { |card| card["numero_interno"] }
    def cards_by_name = @cards_by_name ||= cards.index_by { |card| card["nome"] }

    # ---- pacotes ---------------------------------------------------------------------

    def import_packs
      availability = load("disponibilidade.yml")
      rows = packs.map do |pack|
        { name: pack["nome"], position: pack["ordem"], price: pack["preco"], cards_per_pack: pack["cartas_por_pacote"],
          availability: availability.fetch(pack["nome"]), source_revision: pack["fonte"] }
      end
      Pack.upsert_all(rows, unique_by: :name, record_timestamps: true)
      Pack.where.not(name: rows.pluck(:name)).destroy_all
      pack_ids = Pack.pluck(:name, :id).to_h
      insert(PackCard, packs.flat_map { |pack| pack_card_rows(pack, pack_ids.fetch(pack["nome"])) })
    end

    def packs = @packs ||= load("pacotes.yml")

    def pack_card_rows(pack, pack_id)
      contents(pack).filter_map { |item| [ card_id(item), item["raridade"] ] }
                    .select(&:first).uniq(&:first)
                    .map { |card_id, rarity| { pack_id:, card_id:, rarity: RARITIES.fetch(rarity) } }
    end

    # Pacote que junta outros (inclui) leva as cartas deles, na raridade de origem.
    def contents(pack)
      rule = pack["inclui"]
      return pack["cartas"] unless rule

      sources = packs.reject { |other| other["inclui"] }
      if rule["primeiros_pacotes"]
        sources = sources.select { |other| other["ordem"] <= rule["primeiros_pacotes"] && rule["exceto"].exclude?(other["nome"]) }
      end
      sources.flat_map { |other| other["cartas"] } + pack["cartas"]
    end

    # ---- banlist e conversor ---------------------------------------------------------

    def import_banlist
      banlist = load("banlist.yml")
      Banlist.upsert({ name: DEFAULT_BANLIST, source_revision: banlist["fonte"] }, unique_by: :name, record_timestamps: true)
      banlist_id = Banlist.find_by!(name: DEFAULT_BANLIST).id
      rows = banlist["cartas"].filter_map do |item|
        id = card_id(item)
        id && { banlist_id:, card_id: id, status: STATUSES.fetch(item["status"]) }
      end
      insert(BanlistEntry, rows.uniq { |row| row[:card_id] })
    end

    def import_converter
      groups = load("conversor.yml")["grupos"]
      ConverterGroup.upsert_all(groups.keys.map { |amount| { amount: } }, unique_by: :amount, record_timestamps: true)
      ConverterGroup.where.not(amount: groups.keys).destroy_all
      group_ids = ConverterGroup.pluck(:amount, :id).to_h
      rows = groups.flat_map do |amount, names|
        names.filter_map { |name| card_id("nome" => name) }.uniq.map { |id| { converter_group_id: group_ids.fetch(amount), card_id: id } }
      end
      insert(ConverterGroupCard, rows)
    end

    def insert(model, rows)
      model.insert_all!(rows, record_timestamps: true) if rows.any?
    end
  end
end
