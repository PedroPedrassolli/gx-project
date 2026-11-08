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

    # Imagem do YGOPRODeck: a do passcode (a pré-errata usa a da carta oficial); na carta do
    # anime que usa a impressão posterior, a da impressão. As outras do anime não têm.
    def image_code(card, exceptions)
      exception = exceptions[key(card)]
      return card["passcode"] unless exception
      return unless exception["imagem"]

      exception["motivo"] == "usar_oficial" ? exception["codigo"] : card["passcode"]
    end

    def image_codes(seeds) = each_code(seeds) { |card, exceptions| image_code(card, exceptions) }

    def each_code(seeds)
      exceptions = exceptions(seeds)
      YAML.safe_load_file(File.join(seeds, "cartas.yml")).filter_map { |card| yield card, exceptions }.uniq
    end
  end
end
