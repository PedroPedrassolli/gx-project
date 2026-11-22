module Catalog
  # O catálogo inteiro na memória, pronto para a API: cartas, pacotes e banlists viram
  # hashes uma vez só, e cada pedido filtra em Ruby (são umas 3.500 cartas). A versão, um
  # resumo do conteúdo, vira o ETag (ADR 0007).
  #
  # Só remonta quando o banco muda (GXP-120): no máximo a cada 30 s, uma consulta barata
  # confere o carimbo das tabelas do catálogo. Antes, remontava a cada 5 minutos, e o pedido
  # que caía na hora esperava mais de 1 s.
  class Snapshot
    CHECK_EVERY = 30.seconds
    SOURCE = "https://yugipedia.com/index.php?oldid=%d".freeze
    SORTS = { "name" => :name, "atk" => :atk, "def" => :def, "level" => :level, "type" => :card_type }.freeze
    # As colunas das cartas que a API usa: sem criar um objeto do Rails por carta, a montagem
    # fica umas 3 vezes mais rápida.
    COLUMNS = %i[id engine_code name name_pt card_type property card_attribute race monster_types level attack defense
                 image_code passcode name_in_game text text_pt text_pt_unofficial source_revision].freeze
    LOCK = Mutex.new

    attr_reader :version, :stamp, :packs, :banlists

    # Um pedido por vez: quem chega enquanto outro monta espera o mesmo catálogo, em vez de
    # montar outro junto.
    def self.current
      LOCK.synchronize do
        snapshot = @current
        next snapshot if snapshot&.checked_recently?

        stamp = self.stamp
        next snapshot.checked! if snapshot&.stamp == stamp

        @current = new(stamp)
      end
    end

    def self.reset! = @current = nil

    # O carimbo dos dados: o importador grava as tabelas com updated_at, e as linhas dos
    # pacotes e da banlist são regravadas a cada importação.
    def self.stamp
      ApplicationRecord.connection.select_rows(<<~SQL).first
        SELECT (SELECT max(updated_at) FROM cards), (SELECT max(updated_at) FROM packs),
               (SELECT max(updated_at) FROM pack_cards), (SELECT max(updated_at) FROM banlist_entries),
               (SELECT count(*) FROM pack_cards), (SELECT count(*) FROM banlist_entries)
      SQL
    end

    # Ao subir o servidor (config/puma.rb), em segundo plano: abre a conexão com o banco e
    # monta o catálogo antes de alguém pedir. Se falhar, fica no log, e o primeiro pedido
    # tenta de novo.
    def self.warm_up
      Rails.application.executor.wrap { current }
    rescue StandardError => error
      Rails.logger.warn("O catálogo não aqueceu: #{error.class}: #{error.message}")
    end

    def initialize(stamp = self.class.stamp)
      @stamp = stamp
      @checked_at = Time.current
      @pack_cards = PackCard.pluck(:card_id, :pack_id, :rarity).group_by(&:first)
      @statuses = BanlistEntry.joins(:banlist).where(banlists: { name: Importer::DEFAULT_BANLIST })
                              .pluck(:card_id, :status).to_h
      rows = Card.order(:name, :id).pluck(*COLUMNS).map { |values| COLUMNS.zip(values).to_h }
      @cards = rows.map { |card| summary(card) }
      @names = rows.to_h { |card| [ card[:id], plain([ card[:name], card[:name_pt], card[:name_in_game] ].compact.join(" | ")) ] }
      @by_id = @cards.index_by { |card| card[:id] }
      @extras = rows.to_h { |card| [ card[:id], extra(card) ] }
      @packs = Pack.order(:position).map { |pack| pack_row(pack) }
      @banlists = Banlist.order(:id).includes(:entries).map { |banlist| banlist_row(banlist) }
      @version = Digest::SHA256.hexdigest(JSON.generate([ @cards, @extras, @packs, @banlists ]))[0, 16]
    end

    def checked_recently? = @checked_at > CHECK_EVERY.ago

    def checked!
      @checked_at = Time.current
      self
    end

    # Cartas que passam nos filtros (escopo 3.3), na ordem pedida. Com pacote, cada carta
    # vem com a raridade nele. Valor que não existe não filtra nada: devolve vazio.
    def search(filters)
      filters = filters.merge(q: plain(filters[:q])) if filters[:q].present?
      rows = @cards.select { |card| match?(card, filters) }
      if (pack = integer(filters[:pack]))
        rarities = pack_rarities(pack)
        rows = rows.filter_map { |card| rarities[card[:id]] && card.merge(rarity: rarities[card[:id]]) }
      end
      sort(rows, filters[:sort], filters[:order])
    end

    # O detalhe de uma carta: o resumo da lista e o que só o detalhe traz.
    def card(id)
      id = integer(id)
      @by_id[id]&.merge(@extras[id])
    end

    # O que só o detalhe traz (textos, pacotes, fonte), de todas as cartas, pelo id: o front
    # baixa num pedido só e junta com o resumo que já tem (GXP-121).
    def details = @extras

    private

    # ---- linhas da resposta -------------------------------------------------------------

    def summary(card)
      # code: o código da carta na engine; é com ele que o duelo fala das cartas (GXP-51).
      { id: card[:id], code: card[:engine_code], name: card[:name], name_pt: card[:name_pt], card_type: card[:card_type],
        property: card[:property], attribute: card[:card_attribute], race: card[:race], monster_types: card[:monster_types].presence,
        level: card[:level], atk: card[:attack], def: card[:defense], banlist: @statuses[card[:id]], image: card[:image_code] }.compact
    end

    def extra(card)
      packs = @pack_cards.fetch(card[:id], []).map { |_card, pack_id, rarity| { id: pack_id, rarity: } }
      { passcode: card[:passcode], name_in_game: card[:name_in_game], text: card[:text], text_pt: card[:text_pt],
        text_pt_unofficial: (true if card[:text_pt_unofficial]), packs: packs.presence,
        source: format(SOURCE, card[:source_revision]) }.compact
    end

    # Sem a regra de liberação: ela fica só no servidor (a loja diz a cada jogador o que falta),
    # e a regra "codigo" traz o código secreto (GXP-89).
    def pack_row(pack)
      { id: pack.id, name: pack.name, position: pack.position, price: pack.price, cards_per_pack: pack.cards_per_pack,
        card_count: pack_rarities(pack.id).size }
    end

    def banlist_row(banlist)
      { id: banlist.id, name: banlist.name, entries: banlist.entries.map { |entry| { card_id: entry.card_id, status: entry.status } } }
    end

    def pack_rarities(pack_id)
      @pack_rarities ||= @pack_cards.values.flatten(1).group_by { |_card, pack, _rarity| pack }
                                    .transform_values { |items| items.to_h { |card, _pack, rarity| [ card, rarity ] } }
      @pack_rarities.fetch(pack_id, {})
    end

    # ---- filtros ------------------------------------------------------------------------

    def match?(card, filters)
      text_match?(card, filters[:q]) &&
        same?(card[:card_type], filters[:card_type]) && same?(card[:property], filters[:property]) &&
        same?(card[:attribute], filters[:attribute]) && same?(card[:race], filters[:race]) &&
        (filters[:monster_type].blank? || card[:monster_types].to_a.any? { |type| same?(type, filters[:monster_type]) }) &&
        (filters[:level].blank? || card[:level] == integer(filters[:level])) &&
        within?(card[:atk], filters[:atk_min], filters[:atk_max]) && within?(card[:def], filters[:def_min], filters[:def_max])
    end

    # Nome em inglês, em português ou o que o jogo usava, sem diferença de acento e de caixa.
    def text_match?(card, query) = query.blank? || @names[card[:id]].include?(query)

    def plain(text) = text.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").downcase

    def same?(value, wanted) = wanted.blank? || value.to_s.casecmp?(wanted.to_s)

    # Faixa de ATK ou DEF. Monstro com "?" (sem valor) fica de fora quando há faixa.
    def within?(value, min, max)
      return true if min.blank? && max.blank?

      !value.nil? && value >= (integer(min) || 0) && value <= (integer(max) || Float::INFINITY)
    end

    def integer(value) = Integer(value.to_s, 10, exception: false)

    # Ordena pelo campo pedido, crescente ou decrescente ("desc"), e desempata pelo nome.
    # Carta sem o valor (magia sem nível, ATK "?") vai para o fim.
    def sort(rows, field, order)
      key = SORTS.fetch(field.to_s, :name)
      direction = order.to_s == "desc" ? -1 : 1
      with_value, without = rows.partition { |card| card[key] }
      with_value.sort { |a, b| ((a[key] <=> b[key]) * direction).nonzero? || a[:name] <=> b[:name] } + without
    end
  end
end
