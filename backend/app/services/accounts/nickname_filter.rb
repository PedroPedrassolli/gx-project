module Accounts
  # Barra apelido com palavrão ou ofensa (escopo 3.1; ADR 0008). A lista é curta e nossa:
  # config/nickname_blocklist.yml. Palavra de 5 letras ou mais é barrada em qualquer parte
  # do apelido; palavra curta, só quando aparece separada ("Paulo" passa, "Pau_Mole" não),
  # para não barrar nome comum.
  module NicknameFilter
    BLOCKLIST = YAML.load_file(Rails.root.join("config/nickname_blocklist.yml")).values.flatten.freeze
    LONG_WORD = 5
    # Números usados no lugar de letras ("p0rra").
    DIGITS_AS_LETTERS = { "0" => "o", "1" => "i", "3" => "e", "4" => "a", "5" => "s", "7" => "t" }.freeze

    module_function

    def clean?(nickname)
      words = words(nickname)
      joined = words.join
      BLOCKLIST.none? do |bad|
        bad.length >= LONG_WORD ? joined.include?(bad) : words.include?(bad) || joined == bad
      end
    end

    # Palavras do apelido, em minúsculas: separa por "_", "-", número e camelCase
    # ("BigBoss" vira "big" e "boss"), depois de trocar os números que fazem papel de letra.
    def words(nickname)
      nickname.gsub(/([a-z])([A-Z])/, '\1 \2').downcase
        .gsub(/[013457]/, DIGITS_AS_LETTERS)
        .split(/[^a-z]+/).reject(&:empty?)
    end
  end
end
