require "test_helper"

describe GameData::EraText do
  def wiki_page(id, title, text) = GameData::Yugipedia::Page.new(id:, revision: id * 10, title:, text:)

  def errata(id, name, versions)
    lines = versions.each_with_index.map { |(lore, caption), index| "| lore#{index} = #{lore}\n| cap#{index} = #{caption}" }
    wiki_page(id, "Card Errata:#{name}", "== English ==\n{{Errata table\n#{lines.join("\n")}\n}}")
  end

  def set(id, title, date) = wiki_page(id, title, "{{Infobox set\n| na_release_date = #{date}\n}}")

  let(:pages) do
    [ errata(1, "Old Card", [ [ "First printed text here.", "[[AAA-001]]<br />[[Set Old]]" ],
                              [ "Text of the year 2006.", "[[BBB-001]]<br />[[Set Mid]]<br />''[[Set New]]''" ],
                              [ "Text after the errata.", "[[CCC-001]]<br />[[Set New]]" ] ]),
      errata(2, "Late Card", [ [ "Only printed late.", "[[DDD-001]]<br />[[Set New]]" ],
                               [ "Printed even later.", "{{database link|1}}" ] ]),
      errata(3, "Stat Card", [ [ "DEF/3800", "[[AAA-002]]<br />[[Set Old]]" ] ]),
      errata(4, "Listed Card", [ [ "Old list text was.", "[http://web.archive.org/web/20070101000000/http://x.com FAQ]" ],
                                 [ "New list text is.", "[http://x.com/list.pdf Errata list (January 5, 2010)]" ] ]),
      set(10, "Set Old", "June 26, 2002"), set(11, "Set Mid", "May 1, 2006"), set(12, "Set New", "August 4, 2011") ]
  end
  let(:client) { GameData::FakeYugipedia.new(category: [], fixed: {}, cards: pages) }
  let(:texts) { GameData::EraText.new(client, Date.new(2008, 11, 28)).texts([ "Old Card", "Late Card", "Stat Card", "Listed Card", "No Page" ]) }

  it "escolhe a última versão impressa até o jogo sair, pela data do primeiro pacote" do
    _(texts["Old Card"]).must_equal({ texto: "Text of the year 2006.", fonte: 10 })
  end

  it "usa a primeira versão quando nenhuma saiu antes do jogo" do
    _(texts["Late Card"]).must_equal({ texto: "Only printed late.", fonte: 20 })
  end

  it "lê a data da legenda sem pacote e ignora mudança só de número" do
    _(texts["Listed Card"][:texto]).must_equal "Old list text was."
    _(texts.keys).wont_include "Stat Card"
    _(texts.keys).wont_include "No Page"
  end
end
