module GameData
  # De onde vem a imagem das cartas do anime sem impressão oficial (GXP-142), pela API da
  # Yugipedia: a imagem da página da carta, quando é a de uma carta impressa em inglês (a
  # promocional); senão, a da página da carta no jogo de referência. Essa é uma tela de
  # informações do jogo, com a carta no canto, e o workflow das imagens recorta a carta dela.
  class CardPictures
    SCREEN = "-VG-info." # arquivo de tela de jogo, e não de carta impressa
    ENGLISH = /-(?:EN|NA|AE)-/ # impressão em inglês: EN, NA (América do Norte) ou AE (Ásia)
    CROP = "5 4 108 154" # onde fica a carta na tela: x, y, largura e altura (o -crop do cwebp)

    def initialize(client)
      @client = client
    end

    # cards: [{ code:, name:, source: }] (GameData::Pool.yugipedia_cards). Uma linha por carta,
    # separada por tab: o código, o endereço da imagem e, na tela de jogo, o recorte.
    def lines(cards)
      printed = @client.images_by_title(cards.map { |card| card[:name] })
      screens = @client.images_by_revision(cards.map { |card| card[:source] })
      cards.filter_map do |card|
        url = printed[card[:name]]
        next [ card[:code], url ].join("\t") if url&.match?(ENGLISH) && !url.include?(SCREEN)

        screen = screens[card[:source]]
        [ card[:code], screen, CROP ].join("\t") if screen
      end
    end
  end
end
