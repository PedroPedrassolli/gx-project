module GameData
  # Monta os dados do jogo de referência a partir da Yugipedia e devolve o texto dos YAML de
  # db/seeds/jogo. O título das páginas traz o nome do jogo, que não entra no repositório
  # (ADR 0003): por isso as páginas vão pelo id, e a fonte de cada dado é a revisão (oldid).
  class Export
    SETS_CATEGORY = 938_407   # categoria com os pacotes, o deck inicial e o conversor
    GAME = 32_602             # página do jogo: total de cartas e as Destiny do deck inicial
    INITIAL_DECK = 46_497
    CONVERTER = 987_199
    CHALLENGES = 1_025_416
    BANLIST = 1_054_589
    DLC = 1_093_942
    MINIGAME_PRIZES = 710_773 # cartas que só saem num minigame

    RARITIES = { "Ultra Rare" => "ultra_rara", "Super Rare" => "super_rara", "Rare" => "rara",
                 "Common" => "comum" }.freeze
    STATUSES = { "Forbidden" => "proibida", "Limited" => "limitada",
                 "Semi-Limited" => "semi_limitada" }.freeze
    LICENSE = "# Dados da Yugipedia (CC BY-SA), reorganizados. Veja o README desta pasta.".freeze

    def initialize(client)
      @client = client
    end

    # { "arquivo.yml" => texto do arquivo }
    def files
      {
        "cartas.yml" => cards_file, "pacotes.yml" => packs_file,
        "deck_inicial.yml" => initial_deck_file, "conversor.yml" => converter_file,
        "desafios.yml" => challenges_file, "banlist.yml" => banlist_file,
        "extras.yml" => extras_file
      }
    end

    # Conferências que o rake mostra: total de cartas, tamanho dos pacotes que juntam
    # outros e títulos que não acharam página.
    def checks
      pool = "#{cards.size} cartas; a página do jogo diz #{page(GAME).text[/total of (\d+) cards/, 1]}"
      sizes = packs.select { |pack| pack[:includes] }.map do |pack|
        "#{pack[:name]}: #{pack_contents(pack).size} cartas pela regra; a página diz #{pack[:size]}"
      end
      unidentified = cards.count { |card| card.slice(:passcode, :numero_interno).compact.empty? }
      [ pool, *sizes, "#{unidentified} cartas sem passcode nem número interno",
        *missing_titles.map { |title| "sem página: #{title}" } ]
    end

    private

    # ---- páginas ---------------------------------------------------------------------

    def page(id)
      @fixed ||= @client.pages_by_id([ GAME, INITIAL_DECK, CONVERTER, CHALLENGES, BANLIST, DLC,
                                       MINIGAME_PRIZES ])
      @fixed.fetch(id)
    end

    def packs
      @packs ||= begin
        sets = @client.pages_by_title(@client.category_members(SETS_CATEGORY)).values
        boosters = sets.select { |set| Wikitext.field(set.text, "type").to_s.include?("Booster Pack") }
        shop_order(boosters).map.with_index(1) { |set, order| pack(set, order) }
      end
    end

    # A ordem da loja vem da infobox: cada pacote aponta o anterior (prev) e o próximo (next).
    def shop_order(sets)
      by_title = sets.index_by(&:title)
      current = sets.find { |set| Wikitext.field(set.text, "prev").nil? }
      order = []
      while current && order.exclude?(current)
        order << current
        current = by_title[Wikitext.field(current.text, "next")]
      end
      order + (sets - order)
    end

    def pack(set, order)
      price = Wikitext.pack_price(set.text) || {}
      { name: Wikitext.field(set.text, "en_name"), order:, price: price[:price],
        per_pack: price[:cards], size: Wikitext.field(set.text, "size")&.to_i,
        includes: includes(set.text), source: set.revision,
        cards: Wikitext.set_list(set.text).map { |item| item.merge(rarity: rarity(item[:rarity])) } }
    end

    # Pacotes que juntam outros: "all cards from the first 34 packs (except for ...)" ou
    # "all cards from all other packs".
    def includes(text)
      if (first = text[/all cards from the first (\d+) packs/, 1])
        { primeiros_pacotes: first.to_i, exceto: text.scan(/except for ''\[\[[^|\]]+\|([^\]]+)\]\]''/).flatten }
      elsif text.include?("all cards from all other packs")
        { todos_os_pacotes: true }
      end
    end

    # Cartas de um pacote que junta outros, na raridade de origem, mais as do próprio pacote.
    def pack_contents(pack)
      rule = pack[:includes]
      sources = packs.reject { |other| other.equal?(pack) || other[:includes] }
      if rule[:primeiros_pacotes]
        sources = sources.select { |other| other[:order] <= rule[:primeiros_pacotes] }
                         .reject { |other| rule[:exceto].include?(other[:name]) }
      end
      (sources.flat_map { |other| other[:cards] } + pack[:cards]).map { |item| key(item[:title]) }.uniq
    end

    def rarity(name)
      name && RARITIES.fetch(name) { raise Yugipedia::Error, "raridade desconhecida: #{name}" }
    end

    # ---- cartas ------------------------------------------------------------------------

    def initial_deck = Wikitext.set_list(page(INITIAL_DECK).text)
    def side_deck = Wikitext.set_list(Wikitext.section(page(INITIAL_DECK).text, "Side Deck"))
    def converter = Wikitext.converter_groups(page(CONVERTER).text)
    def banlist = Wikitext.limitation_list(page(BANLIST).text)
    def dlc = Wikitext.linked_items(page(DLC).text, "Downloadable cards")
    def prizes = Wikitext.set_list(page(MINIGAME_PRIZES).text).pluck(:title)

    # Todos os títulos de carta das listas. Os pacotes vêm primeiro: o nome que aparece neles
    # é o do jogo.
    def titles
      @titles ||= (packs.flat_map { |pack| pack[:cards].pluck(:title) } +
                   (initial_deck + side_deck).pluck(:title) + converter.values.flatten +
                   banlist.pluck(:title) + dlc + prizes).uniq
    end

    # { título => página da carta }. Cada título pode ter duas páginas: a da carta no jogo
    # (o título inteiro, com o qualificador) e a da carta oficial (sem o qualificador, com o
    # redirecionamento do nome antigo para o atual).
    def card_pages
      @card_pages ||= begin
        in_game = card_pages_by_title(titles)
        @official = official_pages
        chosen = titles.each_with_object({}) do |title, found|
          card = choose(title, in_game[title], @official[Wikitext.base_title(title)])
          found[title] = card if card
        end
        same_name_ignoring_case(chosen)
      end
    end

    # Título sem página que só difere de outra carta na caixa das letras ("Feeds On Life" e
    # "Feeds on Life"): a Yugipedia diferencia, o jogo não.
    def same_name_ignoring_case(chosen)
      by_name = chosen.values.index_by { |card| Wikitext.card_name(card.title).downcase }
      (titles - chosen.keys).each do |title|
        card = by_name[Wikitext.card_name(title).downcase]
        chosen[title] = card if card
      end
      chosen
    end

    # Página oficial de cada título, sem o qualificador do jogo. Quando o nome puro é de
    # outra coisa (pacote, arquétipo, episódio), a carta está em "Nome (card)" ou na página
    # que o aviso do topo indica ("For the card, see Penalty Game!").
    def official_pages
      bases = titles.map { |title| Wikitext.base_title(title) }.uniq
      pages = @client.pages_by_title(bases, section: 0)
      options = bases.reject { |base| card_page?(pages[base]) }.index_with do |base|
        [ "#{base} (card)", Wikitext.card_hatnote(pages[base]&.text.to_s) ].compact
      end
      found = card_pages_by_title(options.values.flatten.uniq)
      bases.index_with do |base|
        card_page?(pages[base]) ? pages[base] : options[base].filter_map { |title| found[title] }.first
      end.compact
    end

    # Só vale página com a caixa de uma carta.
    def card_pages_by_title(titles)
      @client.pages_by_title(titles, section: 0).select { |_title, page| card_page?(page) }
    end

    def card_page?(page) = page.present? && Wikitext.card_infobox?(page.text)

    # Carta do anime que o jogo trouxe vale pela página do jogo, mesmo que o OCG tenha
    # impresso uma carta com o mesmo nome depois. As outras valem pela carta oficial (com
    # passcode e o nome atual); sem ela, pela página do jogo.
    def choose(title, in_game, official)
      return in_game if in_game && anime_titles.include?(title)
      return official if official && passcode(official)

      in_game || official
    end

    # Cartas do anime listadas na página do jogo.
    def anime_titles
      @anime_titles ||= Wikitext.links(Wikitext.section(page(GAME).text, "Anime original cards")).to_set
    end

    def missing_titles = titles - card_pages.keys

    # Uma entrada por carta (pelo passcode ou pelo número interno), na ordem das listas.
    def cards
      @cards ||= titles.filter_map { |title| [ card_pages[title], title ] if card_pages[title] }
                       .uniq { |card, _title| identity_key(card) }
                       .map { |card, title| card_entry(card, title) }
    end

    def card_entry(card, title)
      name = Wikitext.card_name(card.title)
      name_in_game = Wikitext.card_name(title)
      { nome: name, nome_no_jogo: (name_in_game unless name_in_game == name), **identity(card),
        passcode_oficial: printed_version(card, title), fonte: card.revision }
    end

    # Carta do anime que o OCG imprimiu depois (com outro efeito ou outro nome): o passcode
    # da impressão, que a cobertura usa quando não há script da versão do jogo.
    def printed_version(card, title)
      official = @official[Wikitext.base_title(title)]
      passcode(official) if official && official.id != card.id && passcode(card).nil?
    end

    # Carta oficial tem passcode; versão que só existe no jogo tem o número interno dele.
    def identity(card)
      code = passcode(card)
      code ? { passcode: code } : { numero_interno: number(card, "internal_number") }.compact
    end

    def passcode(card) = number(card, "password")

    def number(card, field)
      value = Wikitext.field(card.text, field)
      value.to_i if value&.match?(/\A\d+\z/)
    end

    # Chave para juntar a mesma carta vinda de páginas diferentes.
    def identity_key(card) = identity(card).presence || { pagina: card.id }

    # Como as outras listas citam uma carta: nome atual e passcode (ou número interno).
    def reference(title)
      card = card_pages[title]
      return { nome: Wikitext.card_name(title), sem_pagina: true } unless card

      { nome: Wikitext.card_name(card.title), **identity(card) }
    end

    def key(title) = card_pages[title] ? identity_key(card_pages[title]) : title

    # ---- arquivos ----------------------------------------------------------------------

    def cards_file
      document([ "Cartas do jogo de referência, uma por página da Yugipedia.",
                 "nome_no_jogo: o nome que o jogo usa, quando mudou depois.",
                 "passcode_oficial: carta do anime que o OCG imprimiu depois; o passcode da impressão.",
                 "fonte: revisão da página da carta (yugipedia.com/index.php?oldid=N)." ],
               cards.map { |card| "- #{flow(card)}" })
    end

    def packs_file
      body = packs.flat_map do |pack|
        [ "- nome: #{json(pack[:name])}", "  ordem: #{pack[:order]}", "  preco: #{json(pack[:price])}",
          "  cartas_por_pacote: #{json(pack[:per_pack])}", "  tamanho: #{json(pack[:size])}",
          *("  inclui: #{flow(pack[:includes])}" if pack[:includes]), "  fonte: #{pack[:source]}",
          "  cartas:#{' []' if pack[:cards].empty?}",
          *pack[:cards].map { |item| "    - #{flow(reference(item[:title]).merge(raridade: item[:rarity]))}" } ]
      end
      document([ "Pacotes da loja, na ordem do jogo, com preço em DP e as cartas com a raridade.",
                 "inclui: pacote que junta as cartas de outros, na raridade de origem.",
                 "fonte: revisão da página do pacote (yugipedia.com/index.php?oldid=N)." ], body)
    end

    def initial_deck_file
      destiny = Wikitext.destiny_cards(Wikitext.section(page(GAME).text, "Starting Deck"))
      deck = ->(list) { list.map { |item| "  - #{flow(reference(item[:title]).merge(quantidade: item[:quantity]))}" } }
      document([ "Deck com que o jogador começa.",
                 "fonte: revisão das páginas do deck e do jogo (marcação de Destiny)." ],
               [ "fonte: [#{page(INITIAL_DECK).revision}, #{page(GAME).revision}]", "principal:",
                 *deck.call(initial_deck), "side:", *deck.call(side_deck),
                 "destiny: #{json(destiny.map { |title| reference(title)[:nome] })}" ])
    end

    def converter_file
      document([ "Conversor: o jogador põe de 10 a 99 cartas repetidas e ganha 1 carta sorteada",
                 "do grupo da quantidade." ],
               [ "fonte: #{page(CONVERTER).revision}", "grupos:",
                 *converter.sort.map { |amount, group| "  #{amount}: #{json(group.map { |title| reference(title)[:nome] })}" } ])
    end

    def challenges_file
      items = Wikitext.numbered_items(page(CHALLENGES).text, "Challenges")
      document([ "Os desafios, com o texto original em inglês." ],
               [ "fonte: #{page(CHALLENGES).revision}", "desafios:",
                 *items.map { |item| "  - #{flow(numero: item[:number], texto: item[:text])}" } ])
    end

    def banlist_file
      document([ "Banlist padrão do jogo de referência." ],
               [ "fonte: #{page(BANLIST).revision}", "cartas:",
                 *banlist.map { |item| "  - #{flow(reference(item[:title]).merge(status: STATUSES.fetch(item[:status])))}" } ])
    end

    def extras_file
      names = ->(list) { json(list.map { |title| reference(title)[:nome] }) }
      document([ "Cartas que no jogo saem fora dos pacotes: por download (DLC) e num minigame." ],
               [ "dlc:", "  fonte: #{page(DLC).revision}", "  cartas: #{names.call(dlc)}",
                 "minigame:", "  fonte: #{page(MINIGAME_PRIZES).revision}", "  cartas: #{names.call(prizes)}" ])
    end

    def document(notes, lines)
      header = [ *notes.map { |note| "# #{note}" },
                 "# Gerado por `bin/rails dados:jogo`: não edite à mão.", LICENSE ]
      (header + lines).join("\n") + "\n"
    end

    def flow(hash) = "{ #{hash.compact.map { |key, value| "#{key}: #{json(value)}" }.join(', ')} }"
    def json(value) = JSON.generate(value)
  end
end
