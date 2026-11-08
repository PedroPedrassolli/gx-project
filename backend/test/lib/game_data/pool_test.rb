require "test_helper"

describe GameData::Pool do
  let(:seeds) { Rails.root.join("test/fixtures/files/catalogo").to_s }

  it "dá o código da engine de cada carta do pool, sem as que saíram e sem repetir" do
    # Night Assailant usa a pré-errata (110); Clear Wall, o script do anime (900); Labyrinth
    # saiu do pool; as duas Ancient Gear são a mesma carta na engine (500).
    _(GameData::Pool.codes(seeds)).must_equal [ 110, 200, 900, 500, 700 ]
  end

  it "dá a imagem de cada carta: a do passcode ou a da impressão; carta do anime sem impressão fica sem" do
    # Night Assailant (pré-errata) usa a imagem da oficial; Cyril, a da impressão (700).
    _(GameData::Pool.image_codes(seeds)).must_equal [ 100, 200, 500, 700 ]
  end

  it "acha a exceção pela chave da carta" do
    exceptions = GameData::Pool.exceptions(seeds)

    _(GameData::Pool.engine_code({ "nome" => "Trap Hole", "passcode" => 200 }, exceptions)).must_equal 200
    _(GameData::Pool.engine_code({ "nome" => "Labyrinth", "numero_interno" => 4 }, exceptions)).must_be_nil
  end
end
