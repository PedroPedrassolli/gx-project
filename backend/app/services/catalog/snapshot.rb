module Catalog
  # O catálogo inteiro na memória, pronto para a API: cartas, pacotes e banlists viram
  # hashes uma vez só, e cada pedido filtra em Ruby (são umas 3.500 cartas). Recarrega do
  # banco a cada 5 minutos. A versão, um resumo do conteúdo, vira o ETag (ADR 0007).
  class Snapshot
    TTL = 5.minutes
    SOURCE = "https://yugipedia.com/index.php?oldid=%d".freeze
    SORTS = { "name" => :name, "atk" => :atk, "def" => :def, "level" => :level, "type" => :card_type }.freeze

    attr_reader :version, :loaded_at, :packs, :banlists

    def self.current
      @current = nil if @current && @current.loaded_at < TTL.ago
      @current ||= new
    end

    def self.reset! = @current = nil

    def initialize
      @loaded_at = Time.current
      @pack_cards = PackCard.pluck(:card_id, :pack_id, :rarity).group_by(&:first)
      @statuses = BanlistEntry.joins(:banlist).where(banlists: { name: Importer::DEFAULT_BANLIST })
                              .pluck(:card_id, :status).to_h
      records = Card.order(:name, :id).to_a
      @cards = records.map { |card| summary(card) }
      @names = records.to_h { |card| [ card.id, plain([ card.name, card.name_pt, card.name_in_game ].compact.join(" | ")) ] }
      @details = records.to_h { |card| [ card.id, detail(card) ] }
      @packs = Pack.order(:position).map { |pack| pack_row(pack) }
      @banlists = Banlist.order(:id).includes(:entries).map { |banlist| banlist_row(banlist) }
      @version = Digest::SHA256.hexdigest(JSON.generate([ @details, @packs, @banlists ]))[0, 16]
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

    def card(id) = @details[integer(id)]

    private

    # ---- linhas da resposta -------------------------------------------------------------

    def summary(card)
      { id: card.id, name: card.name, name_pt: card.name_pt, card_type: card.card_type, property: card.property,
        attribute: card.card_attribute, race: card.race, monster_types: card.monster_types.presence,
        level: card.level, atk: card.attack, def: card.defense, banlist: @statuses[card.id], image: card.image_code }.compact
    end

    def detail(card)
      packs = @pack_cards.fetch(card.id, []).map { |_card, pack_id, rarity| { id: pack_id, rarity: } }
      summary(card).merge({ passcode: card.passcode, name_in_game: card.name_in_game, text: card.text,
                            text_pt: card.text_pt, packs: packs.presence, source: format(SOURCE, card.source_revision) }.compact)
    end

    def pack_row(pack)
      { id: pack.id, name: pack.name, position: pack.position, price: pack.price, cards_per_pack: pack.cards_per_pack,
        availability: pack.availability, card_count: pack_rarities(pack.id).size }
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
