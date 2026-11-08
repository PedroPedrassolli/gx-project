require "test_helper"

describe GameData::Export do
  def wiki_page(**attributes) = GameData::Yugipedia::Page.new(**attributes)

  def set(id, title, prev:, after:, size:, body:)
    wiki_page(id:, revision: id * 100, title:, text: <<~WIKI)
      {{Infobox set
      | en_name = #{title.sub(' (X)', '')}
      | type    = [[Booster Pack]]
      | size    = #{size}
      | prev    = #{prev}
      | next    = #{after}
      }}
      #{body}
    WIKI
  end

  def fixed(id, text) = [ id, wiki_page(id:, revision: id, title: "Página #{id}", text:) ]

  let(:category) do
    [ set(1, "Pack A (X)", prev: "", after: "Pack B (X)", size: 2,
          body: "Each pack costs 50 DP and contains 5 cards.\n{{Video game set list\n| cards =\nCard One (X); Ultra Rare\nOld Name (X); Common\n}}"),
      set(2, "Pack B (X)", prev: "Pack A (X)", after: "Flag", size: 1,
          body: "Each pack costs 1,000 DP and contains 10 cards.\n{{Video game set list\n| cards =\nGame Card (X); Rare\n}}"),
      set(3, "Flag", prev: "Pack B (X)", after: "Everything", size: 2,
          body: "This pack contains all cards from the first 2 packs in the game (except for ''[[Pack B (X)|Pack B]]'') in the same rarities."),
      set(4, "Everything", prev: "Flag", after: "", size: 4,
          body: "This pack contains all cards from all other packs in the game.\n{{Video game set list\n| cards =\nExtra Card (X); Common\nAnime Card (X); Rare\nNo Code (X); Common\n}}"),
      wiki_page(id: 5, revision: 500, title: "Initial Deck (X)", text: "| type = [[Initial Deck]]") ]
  end

  let(:fixed_pages) do
    export = GameData::Export
    [ fixed(export::GAME, "* The game includes a total of 5 cards.\n== Starting Deck ==\n* [[Card One]] ([[Destiny Draw (rule)|D]])\n" \
                          "== Anime original cards ==\n* [[Anime Card (X)|Anime Card]]\n== Trivia =="),
      fixed(export::INITIAL_DECK, "{{Video game set list\n| cards =\nCard One; Common; 2\n}}\n== Side Deck ==\n{{Video game set list\n| cards =\nOld Name\n}}"),
      fixed(export::CONVERTER, "{{Card converter list\n| cards =\n; 10\n: Card One (X)\n: Labyrinth (X)\n: Penalty (X)\n: extra card (X)\n}}"),
      fixed(export::CHALLENGES, "==Challenges==\n* 001. Won the Match."),
      fixed(export::BANLIST, "{{Limitation status list\n| cards =\nCard One; Limited\n}}"),
      fixed(export::DLC, "==Downloadable cards==\n* [[Missing Card]] - date"),
      fixed(export::MINIGAME_PRIZES, "{{Video game set list\n| cards =\nGame Card (X)\n}}") ].to_h
  end

  let(:cards) do
    [ wiki_page(id: 10, revision: 1000, title: "Card One", text: "{{CardTable2\n| password = 02134346\n}}"),
      wiki_page(id: 11, revision: 1100, title: "New Name", text: "{{CardTable2\n| password = 12345678\n}}"),
      wiki_page(id: 12, revision: 1200, title: "Game Card (X)", text: "{{Game card\n| internal_number = 3778\n}}"),
      wiki_page(id: 13, revision: 1300, title: "Extra Card", text: "{{CardTable2\n| password = 87654321\n}}"),
      wiki_page(id: 14, revision: 1400, title: "Extra Card (X)", text: "{{Game card\n| internal_number = 4000\n}}"),
      wiki_page(id: 15, revision: 1500, title: "Anime Card (X)", text: "{{Game card\n| internal_number = 3800\n}}"),
      wiki_page(id: 16, revision: 1600, title: "Anime Card", text: "{{CardTable2\n| password = 99999999\n}}"),
      wiki_page(id: 17, revision: 1700, title: "No Code", text: "{{CardTable2\n| password = none\n}}"),
      # Nome que é também de um pacote e de um episódio: a carta está em outra página.
      wiki_page(id: 18, revision: 1800, title: "Labyrinth", text: "{{About|the set|the card|\"Labyrinth (card)\"}}\n{{Infobox set\n}}"),
      wiki_page(id: 19, revision: 1900, title: "Labyrinth (card)", text: "{{CardTable2\n| password = 66526672\n}}"),
      wiki_page(id: 20, revision: 2000, title: "Penalty", text: "{{For|the card|\"[[Penalty!]]\"}}\n{{episode\n}}"),
      wiki_page(id: 21, revision: 2100, title: "Penalty!", text: "{{CardTable2\n| password = 00967928<!-- achado no jogo -->\n}}") ]
  end

  let(:export) { GameData::Export.new(GameData::FakeYugipedia.new(category:, fixed: fixed_pages, cards:)) }
  let(:files) { export.files.transform_values { |text| YAML.safe_load(text) } }

  it "grava uma carta por página, com passcode ou número interno e a fonte" do
    _(files["cartas.yml"]).must_equal [
      { "nome" => "Card One", "passcode" => 2_134_346, "fonte" => 1000 },
      { "nome" => "New Name", "nome_no_jogo" => "Old Name", "passcode" => 12_345_678, "fonte" => 1100 },
      { "nome" => "Game Card", "numero_interno" => 3778, "fonte" => 1200 },
      { "nome" => "Extra Card", "passcode" => 87_654_321, "fonte" => 1300 },
      { "nome" => "Anime Card", "numero_interno" => 3800, "passcode_oficial" => 99_999_999, "fonte" => 1500 },
      { "nome" => "No Code", "fonte" => 1700 },
      { "nome" => "Labyrinth", "passcode" => 66_526_672, "fonte" => 1900 },
      { "nome" => "Penalty!", "nome_no_jogo" => "Penalty", "passcode" => 967_928, "fonte" => 2100 }
    ]
    _(export.files["cartas.yml"]).must_include "CC BY-SA"
  end

  it "não aceita página de pacote ou episódio como carta: tenta \"Nome (card)\", o aviso do topo e o nome sem caixa" do
    _(files["conversor.yml"]["grupos"]).must_equal({ 10 => [ "Card One", "Labyrinth", "Penalty!", "Extra Card" ] })
    _(files["cartas.yml"].pluck("fonte")).wont_include 1800
    _(files["cartas.yml"].pluck("fonte")).wont_include 2000
  end

  it "grava os pacotes na ordem da loja, com preço, raridade e os que juntam outros" do
    packs = files["pacotes.yml"]

    _(packs.pluck("nome")).must_equal [ "Pack A", "Pack B", "Flag", "Everything" ]
    _(packs[1].slice("ordem", "preco", "cartas_por_pacote", "tamanho", "fonte"))
      .must_equal({ "ordem" => 2, "preco" => 1000, "cartas_por_pacote" => 10, "tamanho" => 1, "fonte" => 200 })
    _(packs[0]["cartas"]).must_equal [
      { "nome" => "Card One", "passcode" => 2_134_346, "raridade" => "ultra_rara" },
      { "nome" => "New Name", "passcode" => 12_345_678, "raridade" => "comum" }
    ]
    _(packs[2]["inclui"]).must_equal({ "primeiros_pacotes" => 2, "exceto" => [ "Pack B" ] })
    _(packs[2]["cartas"]).must_equal []
    _(packs[3]["inclui"]).must_equal({ "todos_os_pacotes" => true })
  end

  it "grava o deck inicial, o conversor, os desafios, a banlist e os extras" do
    _(files["deck_inicial.yml"]).must_equal({
      "fonte" => [ GameData::Export::INITIAL_DECK, GameData::Export::GAME ],
      "principal" => [ { "nome" => "Card One", "passcode" => 2_134_346, "quantidade" => 2 } ],
      "side" => [ { "nome" => "New Name", "passcode" => 12_345_678, "quantidade" => 1 } ],
      "destiny" => [ "Card One" ]
    })
    _(files["conversor.yml"]["grupos"][10]).must_include "Card One"
    _(files["desafios.yml"]["desafios"]).must_equal [ { "numero" => 1, "texto" => "Won the Match." } ]
    _(files["banlist.yml"]["cartas"]).must_equal [ { "nome" => "Card One", "passcode" => 2_134_346, "status" => "limitada" } ]
    _(files["extras.yml"]["dlc"]["cartas"]).must_equal [ "Missing Card" ]
    _(files["extras.yml"]["minigame"]["cartas"]).must_equal [ "Game Card" ]
  end

  it "confere o total, o tamanho dos pacotes que juntam outros e o que ficou sem página" do
    _(export.checks).must_equal [
      "8 cartas; a página do jogo diz 5",
      "Flag: 2 cartas pela regra; a página diz 2",
      "Everything: 6 cartas pela regra; a página diz 4",
      "1 cartas sem passcode nem número interno",
      "sem página: Missing Card"
    ]
  end

  it "recusa raridade que não conhece" do
    category[0] = set(1, "Pack A (X)", prev: "", after: "", size: 1,
                      body: "{{Video game set list\n| cards =\nCard One (X); Secret Rare\n}}")

    _ { export.files }.must_raise GameData::Yugipedia::Error
  end
end
