require "test_helper"

describe GameData::Auxiliary do
  let(:engine) { Rails.root.join("vendor/engine") }

  def codes(pool) = GameData::Auxiliary.codes(scripts: engine.join("CardScripts").to_s, database: engine.join("BabelCDB/cards.cdb").to_s, pool:)

  it "acha as fichas de cada arte que as cartas do pool criam, em ordem e sem repetir" do
    # Scapegoat (73915051) cria as quatro Sheep Token com "id+i"; Fires of Doomsday
    # (46173679), as duas Doomsday Token.
    found = codes([ 73915051, 46173679 ])

    _(found).must_equal found.sort.uniq
    _([ 46173680, 46173681, 73915052, 73915053, 73915054, 73915055 ] - found).must_be_empty
  end

  it "acha a ficha citada por uma constante do constant.lua" do
    _(codes([ 76524506 ])).must_equal [ 71645243 ] # Garden Rose Flora cria a TOKEN_ROSE
  end

  it "deixa de fora o que já está no pool e o código sem script" do
    # 46173680 está no pool (como se fosse uma carta); 1 não tem script.
    _(codes([ 1, 46173680 ])).must_equal [ 46173681 ]
  end
end
