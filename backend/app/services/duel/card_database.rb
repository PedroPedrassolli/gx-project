require "sqlite3"

module Duel
  # Dados das cartas que a engine pede durante o duelo (tipo, ATK, DEF...).
  # Vêm dos arquivos .cdb (SQLite) do BabelCDB, que entra como submódulo: o repositório
  # guarda só o endereço e o commit, não os dados (docs/adr/0001-engine.md).
  class CardDatabase
    TYPE_LINK = 0x4000000
    DEFAULT_FILES = %w[cards.cdb cards-unofficial.cdb].freeze

    Card = Data.define(:code, :alias_code, :setcodes, :type, :level, :lscale, :rscale,
                       :attack, :defense, :link_marker, :race, :attribute)

    def self.default
      new(DEFAULT_FILES.map { |name| Rails.root.join("vendor/engine/BabelCDB", name) })
    end

    # Quando o mesmo código aparece em dois arquivos, vale o primeiro da lista.
    def initialize(paths)
      @cards = {}
      paths.each { |path| load_file(path) }
      # Lista de setcodes no formato da engine, uma por carta, criada na primeira vez que
      # a engine pede. Fica guardada: a engine lê a lista depois que o callback termina.
      @setcode_pointers = {}
    end

    def size = @cards.size

    def find(code) = @cards[code]

    # Preenche a estrutura que a engine mandou no callback de leitura. Código que não
    # existe fica só com o código (a engine trata como carta sem dados).
    def fill(code, data)
      data[:code] = code
      card = @cards[code]
      data[:setcodes] = setcode_pointer(code, card&.setcodes || [])
      return unless card

      data[:alias] = card.alias_code
      data[:type] = card.type
      data[:level] = card.level
      data[:attribute] = card.attribute
      data[:race] = card.race
      data[:attack] = card.attack
      data[:defense] = card.defense
      data[:lscale] = card.lscale
      data[:rscale] = card.rscale
      data[:link_marker] = card.link_marker
    end

    private

    def load_file(path)
      db = SQLite3::Database.new(path.to_s, readonly: true)
      db.execute("SELECT id, alias, setcode, type, atk, def, level, race, attribute FROM datas") do |row|
        card = build_card(*row)
        @cards[card.code] ||= card
      end
    ensure
      db&.close
    end

    # O .cdb guarda alguns campos "empacotados": até 4 setcodes num inteiro de 64 bits,
    # e as escalas de pêndulo junto com o nível. Monstro Link guarda as setas na DEF.
    def build_card(code, alias_code, setcode, type, attack, defense, level, race, attribute)
      link = type.anybits?(TYPE_LINK)
      Card.new(
        code:, alias_code:, type:, race:, attribute:, attack:,
        setcodes: Array.new(4) { |index| (setcode >> (16 * index)) & 0xffff }.reject(&:zero?),
        level: level & 0xff,
        lscale: (level >> 24) & 0xff,
        rscale: (level >> 16) & 0xff,
        defense: link ? 0 : defense,
        link_marker: link ? defense : 0
      )
    end

    def setcode_pointer(code, setcodes)
      @setcode_pointers[code] ||= FFI::MemoryPointer.new(:uint16, setcodes.size + 1).tap do |pointer|
        pointer.write_array_of_uint16(setcodes + [ 0 ])
      end
    end
  end
end
