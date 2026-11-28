require "test_helper"

describe GameData::CardPictures do
  let(:cards) do
    [ { code: 1, name: "Ulevo", source: 10 }, { code: 2, name: "Zero Sprite", source: 20 },
      { code: 3, name: "Arcana", source: 30 }, { code: 4, name: "Sem Nada", source: 40 } ]
  end
  let(:client) do
    Object.new.tap do |fake|
      fake.define_singleton_method(:images_by_title) do |_titles|
        { "Ulevo" => "https://img/Ulevo-WCS-EN-UR-UE.png", "Zero Sprite" => "https://img/ZeroSprite-JP-EN-VG-info.png",
          "Arcana" => "https://img/Arcana-TFGX-JP-OP.png" }
      end
      fake.define_singleton_method(:images_by_revision) do |_revisions|
        { 20 => "https://img/ZeroSprite-EN-VG-info.png", 30 => "https://img/Arcana-EN-VG-info.png" }
      end
    end
  end

  it "prefere a impressão em inglês; senão, recorta a carta da tela do jogo; sem imagem, fica de fora" do
    _(GameData::CardPictures.new(client).lines(cards)).must_equal [
      "1\thttps://img/Ulevo-WCS-EN-UR-UE.png",
      "2\thttps://img/ZeroSprite-EN-VG-info.png\t5 4 108 154",
      "3\thttps://img/Arcana-EN-VG-info.png\t5 4 108 154"
    ]
  end
end
