require "test_helper"

describe Duel::CardSummary do
  it "resume a ficha como o catálogo: só Token, com atributo, tipo, números, texto e imagem" do
    summary = Duel::CardSummary.call(46173680)

    _(summary.except(:text)).must_equal({ code: 46173680, name: "Doomsday Token", card_type: "Monster", attribute: "DARK",
                                          race: "Fiend", monster_types: [ "Token" ], level: 1, atk: 0, def: 0, image: 46173680 })
    _(summary[:text]).must_match(/Fires of Doomsday/)
  end

  it "escreve os tipos do monstro na ordem do catálogo e deixa o ? sem número" do
    synchro = Duel::CardSummary.call(50091196) # Formula Synchron
    _(synchro.values_at(:monster_types, :race, :attribute)).must_equal [ [ "Synchro", "Tuner", "Effect" ], "Machine", "LIGHT" ]
    _(Duel::CardSummary.call(10000).values_at(:atk, :def)).must_equal [ nil, nil ] # Ten Thousand Dragon: ATK e DEF ?
  end

  it "dá a propriedade da magia e da armadilha" do
    _(Duel::CardSummary.call(46173679)[:property]).must_equal "Quick-Play" # Fires of Doomsday
    _(Duel::CardSummary.call(4931121).values_at(:card_type, :property)).must_equal [ "Trap", "Normal" ] # Full Force Virus
  end

  it "não dá imagem para a carta do anime e devolve nil para o código que não existe" do
    _(Duel::CardSummary.call(511000005)).wont_include :image # Toy Soldier, do anime
    _(Duel::CardSummary.call(1)).must_be_nil
  end
end
