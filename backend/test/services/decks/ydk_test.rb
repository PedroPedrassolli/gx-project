require "test_helper"

class Decks::YdkTest < ActiveSupport::TestCase
  let(:file) do
    <<~YDK
      #created by GX Project
      #main
      46986414
      46986414
      5318639
      #extra
      35809262
      !side
      32012841
    YDK
  end

  it "lê os códigos de cada seção, somando as cópias" do
    _(Decks::Ydk.parse(file)).must_equal [
      { section: "main", code: 46986414, quantity: 2 }, { section: "main", code: 5318639, quantity: 1 },
      { section: "extra", code: 35809262, quantity: 1 }, { section: "side", code: 32012841, quantity: 1 }
    ]
  end

  it "ignora linha em branco, comentário e o que não é número" do
    _(Decks::Ydk.parse("#main\n\n# comentário\nabc\n46986414\r\n")).must_equal [ { section: "main", code: 46986414, quantity: 1 } ]
  end

  it "escreve um código por cópia, seção por seção" do
    rows = [ { section: "main", code: 46986414, quantity: 2 }, { section: "main", code: 5318639, quantity: 1 },
             { section: "extra", code: 35809262, quantity: 1 }, { section: "side", code: 32012841, quantity: 1 } ]

    _(Decks::Ydk.dump(rows)).must_equal file
  end
end
