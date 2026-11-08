require "test_helper"

describe GameData::Coverage do
  def row(id, name, type: 0x21, aka: 0, unofficial: false) = { id:, alias: aka, type:, name:, unofficial: }

  let(:cards) do
    [ { "nome" => "Night Assailant", "passcode" => 100 }, { "nome" => "Normal Guy", "passcode" => 200 },
      { "nome" => "Effect Guy", "passcode" => 300 }, { "nome" => "Old Script", "passcode" => 400 },
      { "nome" => "Broken", "passcode" => 500 }, { "nome" => "Clear Wall", "numero_interno" => 1 },
      { "nome" => "Frog-hael", "numero_interno" => 2 }, { "nome" => "Miracle", "numero_interno" => 3 },
      { "nome" => "Advanced Dark", "numero_interno" => 4 }, { "nome" => "Labyrinth" },
      { "nome" => "Cyril", "numero_interno" => 6, "passcode_oficial" => 700 } ]
  end
  let(:database) do
    [ row(100, "Night Assailant"), row(110, "Night Assailant (Pre-Errata)", aka: 100, unofficial: true),
      row(200, "Normal Guy", type: 0x11), row(300, "Effect Guy"), row(400, "Old Script"), row(500, "Broken"),
      row(900, "Clear Wall (VG)", aka: 66, unofficial: true), row(901, "Frog-Hael", unofficial: true),
      row(902, "Miracle (Anime)", unofficial: true), row(600, "Advanced Dark"), row(700, "Ceruli") ]
  end
  let(:scripts) do
    { "official" => Set[100, 300, 600, 700], "pre-errata" => Set[110, 400], "unofficial" => Set[900, 901, 902] }
  end
  let(:coverage) { GameData::Coverage.new(cards:, database:, scripts:, images: Set[100, 200, 300, 600]) }

  it "decide o código e o motivo de cada carta" do
    _(coverage.entries.map { |entry| entry.values_at(:nome, :codigo, :motivo) }).must_equal [
      [ "Night Assailant", 110, "pre_errata" ], [ "Normal Guy", 200, "normal" ], [ "Effect Guy", 300, "oficial" ],
      [ "Old Script", 400, "oficial" ], [ "Broken", 500, "sem_script" ], [ "Clear Wall", 900, "anime" ],
      [ "Frog-hael", 901, "anime" ], [ "Miracle", 902, "anime" ], [ "Advanced Dark", 600, "usar_oficial" ],
      [ "Labyrinth", nil, "tirar_do_pool" ], [ "Cyril", 700, "usar_oficial" ]
    ]
  end

  it "resume a cobertura" do
    _(coverage.summary).must_equal({ cartas: 11, oficiais: 5, normais: 1, pre_errata: 1, anime: 3, usar_oficial: 2,
                                     tirar_do_pool: 1, sem_script: 1, pre_errata_sem_texto: 1, sem_dados: 0,
                                     sem_imagem: 7 })
  end

  it "grava o texto da época das cartas pré-errata, com a fonte" do
    coverage.era_texts = { "Night Assailant" => { texto: "FLIP: Destroy 1 monster.", fonte: 77 } }
    data = YAML.safe_load(coverage.file)

    _(coverage.pre_errata_names).must_equal [ "Night Assailant" ]
    _(data["excecoes"][0].slice("texto", "fonte_texto")).must_equal({ "texto" => "FLIP: Destroy 1 monster.", "fonte_texto" => 77 })
    _(data["excecoes"][1]).wont_include "texto"
    _(data["resumo"]["pre_errata_sem_texto"]).must_equal 0
  end

  it "grava só as exceções, com o script usado nas cartas do anime" do
    data = YAML.safe_load(coverage.file)

    _(data["excecoes"].pluck("nome")).must_equal [ "Night Assailant", "Broken", "Clear Wall", "Frog-hael", "Miracle", "Advanced Dark", "Labyrinth", "Cyril" ]
    _(data["excecoes"][2]).must_equal({ "nome" => "Clear Wall", "numero_interno" => 1, "codigo" => 900,
                                        "motivo" => "anime", "script" => "Clear Wall (VG)", "imagem" => false })
    _(data["resumo"]["cartas"]).must_equal 11
  end
end
