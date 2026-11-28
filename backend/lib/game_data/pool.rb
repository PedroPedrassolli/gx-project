require "yaml"

module GameData
  # Código que a engine usa para cada carta do pool: o passcode, ou o da exceção na
  # cobertura (pré-errata, script do anime, impressão posterior). Carta tirada do pool não
  # tem código. Não depende do Rails: o bin/prune-scripts também usa.
  module Pool
    module_function

    # Exceções do cobertura.yml pela chave da carta.
    def exceptions(seeds)
      YAML.safe_load_file(File.join(seeds, "cobertura.yml"))["excecoes"].to_h { |item| [ key(item), item ] }
    end

    def key(card) = card.values_at("nome", "passcode", "numero_interno")

    def engine_code(card, exceptions)
      exception = exceptions[key(card)]
      return card["passcode"] unless exception

      exception["codigo"] unless exception["motivo"] == "tirar_do_pool"
    end

    def codes(seeds) = each_code(seeds) { |card, exceptions| engine_code(card, exceptions) }

    # O código da imagem da carta: a do passcode (a pré-errata usa a da carta oficial); na carta
    # do anime que usa a impressão posterior, a da impressão. A carta do anime que tem script
    # usa a da impressão oficial de mesmo nome ou a da Yugipedia, publicada pelo código da
    # engine (GXP-142).
    def image_code(card, exceptions)
      exception = exceptions[key(card)]
      return card["passcode"] unless exception

      case exception["imagem"]
      when Integer then exception["imagem"]
      when "yugipedia" then exception["codigo"]
      when true then exception["motivo"] == "usar_oficial" ? exception["codigo"] : card["passcode"]
      end
    end

    # As imagens que vêm do YGOPRODeck (as da Yugipedia ficam de fora: yugipedia_cards).
    def image_codes(seeds)
      each_code(seeds) { |card, exceptions| image_code(card, exceptions) unless yugipedia?(card, exceptions) }
    end

    # As cartas cuja imagem vem da Yugipedia: o código da engine, o nome e a revisão da página
    # da carta (fonte), de onde o workflow das imagens tira a imagem (GameData::CardPictures).
    def yugipedia_cards(seeds)
      each_code(seeds) do |card, exceptions|
        { code: exceptions[key(card)]["codigo"], name: card["nome"], source: card["fonte"] } if yugipedia?(card, exceptions)
      end
    end

    def yugipedia?(card, exceptions) = exceptions.dig(key(card), "imagem") == "yugipedia"

    def each_code(seeds)
      exceptions = exceptions(seeds)
      YAML.safe_load_file(File.join(seeds, "cartas.yml")).filter_map { |card| yield card, exceptions }.uniq
    end
  end
end
