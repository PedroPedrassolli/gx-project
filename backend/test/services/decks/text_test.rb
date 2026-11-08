require "test_helper"

class Decks::TextTest < ActiveSupport::TestCase
  let(:text) do
    <<~TEXT
      Main Deck
      3 Dark Magician
      1 D.D. Assailant (Destiny)

      Extra Deck
      2 Elemental HERO Flame Wingman

      Side Deck
      1 Millennium Shield
    TEXT
  end

  let(:rows) do
    [ { section: "main", name: "Dark Magician", quantity: 3, destiny: false },
      { section: "main", name: "D.D. Assailant", quantity: 1, destiny: true },
      { section: "extra", name: "Elemental HERO Flame Wingman", quantity: 2, destiny: false },
      { section: "side", name: "Millennium Shield", quantity: 1, destiny: false } ]
  end

  it "lê seção, quantidade, nome e Destiny" do
    result = Decks::Text.parse(text)

    _(result.rows).must_equal rows
    _(result.errors).must_be_empty
  end

  it "aceita 3x, seção sem a palavra Deck e carta antes de qualquer seção (vai para o Main)" do
    result = Decks::Text.parse("2x Mago Negro\nside:\n1x Escudo do Milênio (destiny)\n")

    _(result.rows).must_equal [ { section: "main", name: "Mago Negro", quantity: 2, destiny: false },
                                { section: "side", name: "Escudo do Milênio", quantity: 1, destiny: true } ]
  end

  it "avisa as linhas que não entendeu, com o número da linha" do
    result = Decks::Text.parse("Main Deck\nDark Magician\n# comentário\n0 Pot of Greed\n")

    _(result.rows).must_be_empty
    _(result.errors).must_equal [ "Linha 2: não entendi \"Dark Magician\".", "Linha 4: não entendi \"0 Pot of Greed\"." ]
  end

  it "escreve as seções que têm cartas, com as Destiny marcadas" do
    _(Decks::Text.dump(rows)).must_equal text
    _(Decks::Text.dump(rows.first(1))).must_equal "Main Deck\n3 Dark Magician\n"
  end
end
