require "test_helper"

describe GameData::Wikitext do
  let(:wikitext) { GameData::Wikitext }

  it "lê campos da infobox, e campo vazio vira nil" do
    text = "{{Infobox set\n| size   = 68\n| prev   =\n| next   = Beginner Spells (X)\n}}"

    _(wikitext.field(text, "size")).must_equal "68"
    _(wikitext.field(text, "prev")).must_be_nil
    _(wikitext.field(text, "next")).must_equal "Beginner Spells (X)"
    _(wikitext.field(text, "type")).must_be_nil
  end

  it "tira comentário HTML do valor do campo" do
    text = "| password = 39399168<!-- achado no jogo -->\n| lore = Texto <!-- nota\n"

    _(wikitext.field(text, "password")).must_equal "39399168"
    _(wikitext.field(text, "lore")).must_equal "Texto"
  end

  it "lê campo de várias linhas até o próximo campo ou o fim da caixa" do
    text = "{{CardTable2\n| text = Primeira linha\nsegunda linha <!-- nota -->\n| level = 4\n| lore = Última\n}}"

    _(wikitext.long_field(text, "text")).must_equal "Primeira linha\nsegunda linha"
    _(wikitext.long_field(text, "lore")).must_equal "Última"
    _(wikitext.long_field(text, "pt_text")).must_be_nil
  end

  it "limpa a marcação da wiki do texto da carta" do
    text = "Send to the [[Graveyard|GY]]:<br />'''Add''' 1 [[monster]] &quot;Sangan&quot; &amp; <ins>more</ins>\n  ok"

    _(wikitext.plain(text)).must_equal "Send to the GY:\nAdd 1 monster \"Sangan\" & more\nok"
    _(wikitext.plain("When your opponent {{Hover|Summons|Normal Summons}}. {{Hover|*|Nota da wiki}}")).must_equal "When your opponent Summons."
    _(wikitext.plain("")).must_be_nil
    _(wikitext.plain(nil)).must_be_nil
  end

  it "reconhece a caixa de carta, mas não a de pacote, arquétipo ou episódio" do
    _(wikitext.card_infobox?("{{CardTable2\n| password = 1\n}}")).must_equal true
    _(wikitext.card_infobox?("{{About|x|y|z}}\n{{Anime card\n| types = Dragon\n}}")).must_equal true
    _(wikitext.card_infobox?("{{Infobox set\n| type = Booster\n}}")).must_equal false
    _(wikitext.card_infobox?("{{Infobox archseries\n}}\n{{Card converter list\n}}")).must_equal false
  end

  it "acha a carta oficial no aviso do topo da página" do
    for_note = "{{For|the card|\"[[Penalty Game!]]\"}}"
    about = "{{About|the [[archetype]]|the anime card|X (anime)|the card|\"\"Ancient Gear\"\" (card)}}"

    _(wikitext.card_hatnote(for_note)).must_equal "Penalty Game!"
    _(wikitext.card_hatnote(about)).must_equal "Ancient Gear (card)"
    _(wikitext.card_hatnote("{{About|the card|the set|Some Set}}")).must_be_nil
    _(wikitext.card_hatnote("sem aviso")).must_be_nil
  end

  it "separa uma seção até a próxima do mesmo nível" do
    text = "== Um ==\nprimeiro\n=== Sub ===\nainda\n== Dois ==\nsegundo"

    _(wikitext.section(text, "Um")).must_include "ainda"
    _(wikitext.section(text, "Um")).wont_include "segundo"
    _(wikitext.section(text, "Três")).must_equal ""
  end

  it "lê a lista de cartas com raridade e quantidade" do
    text = "{{Video game set list\n| qty = 1\n| cards =\nAsura Priest (X); Ultra Rare\n; 1\nTrap Hole; Common; 2\nRaigeki (X)\n}}"

    _(wikitext.set_list(text)).must_equal [
      { title: "Asura Priest (X)", rarity: "Ultra Rare", quantity: 1 },
      { title: "Trap Hole", rarity: "Common", quantity: 2 },
      { title: "Raigeki (X)", rarity: nil, quantity: 1 }
    ]
    _(wikitext.set_list("sem lista")).must_equal []
  end

  it "tira o último qualificador do título, ou todos para o nome" do
    _(wikitext.base_title("Ancient Gear (card) (X)")).must_equal "Ancient Gear (card)"
    _(wikitext.card_name("Ancient Gear (card) (X)")).must_equal "Ancient Gear"
    _(wikitext.card_name("Kuriboh  (X)")).must_equal "Kuriboh"
    _(wikitext.card_name("Trap Hole")).must_equal "Trap Hole"
  end

  it "lê o preço e quantas cartas vêm no pacote" do
    _(wikitext.pack_price("Each pack costs 1,000 DP and contains 10 cards.")).must_equal({ price: 1000, cards: 10 })
    _(wikitext.pack_price("sem preço")).must_be_nil
  end

  it "agrupa as cartas do conversor pela quantidade" do
    text = "{{Card converter list\n| cards =\n; 10\n: Axe Raider (X)\n: Wolf (X)\n; 11\n: Barox (X)\n}}"

    _(wikitext.converter_groups(text)).must_equal({ 10 => [ "Axe Raider (X)", "Wolf (X)" ], 11 => [ "Barox (X)" ] })
  end

  it "lê os itens numerados de uma seção" do
    text = "==Bonus==\n* 01. Lose - 10 DP\n==Challenges==\n* 001. Won the Match.\n* 104. Won 10 coin tosses."

    _(wikitext.numbered_items(text, "Challenges")).must_equal [
      { number: 1, text: "Won the Match." }, { number: 104, text: "Won 10 coin tosses." }
    ]
  end

  it "lê a banlist" do
    text = "{{Limitation status list\n| date = none\n| cards =\nPot of Greed; Forbidden\nsem status\n}}"

    _(wikitext.limitation_list(text)).must_equal [ { title: "Pot of Greed", status: "Forbidden" } ]
  end

  it "lê os links de uma lista com marcadores" do
    text = "==Downloadable cards==\n* [[Toon Kingdom (X)|Toon Kingdom]] - November 27, 2008\n* [[Skreech]] - date\n==Outra==\n* [[Fora]]"

    _(wikitext.linked_items(text, "Downloadable cards")).must_equal [ "Toon Kingdom (X)", "Skreech" ]
  end

  it "lista os títulos dos links" do
    _(wikitext.links("* [[Clear Cube (X)|Clear Cube]] e [[ Trap Hole ]]")).must_equal [ "Clear Cube (X)", "Trap Hole" ]
  end

  it "acha as cartas marcadas como Destiny no deck" do
    text = "* [[D.D. Assailant]] ([[Destiny Draw (rule)|D]])\n* [[X-Saber Anu Piranha|X-Saber Anapelera]]"

    _(wikitext.destiny_cards(text)).must_equal [ "D.D. Assailant" ]
  end
end
