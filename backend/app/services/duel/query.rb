module Duel
  # Lê as respostas das consultas à engine (OCG_DuelQueryLocation e OCG_DuelQueryField),
  # no formato do ocgapi.cpp e do card.cpp da versão fixada.
  module Query
    # Lugares (LOCATION_* do ocgapi_constants.h).
    DECK = 0x01
    HAND = 0x02
    MONSTERS = 0x04
    SPELLS = 0x08
    GRAVE = 0x10
    BANISHED = 0x20
    EXTRA = 0x40

    # O que perguntar de cada carta (QUERY_*).
    CODE = 0x1
    POSITION = 0x2
    ATTACK = 0x100
    DEFENSE = 0x200
    IS_PUBLIC = 0x100000
    LAST = 0x80000000
    CARD_FLAGS = CODE | POSITION | ATTACK | DEFENSE | IS_PUBLIC

    module_function

    # As cartas de um lugar, na ordem; nil é um espaço vazio (zona sem carta). Cada carta é
    # uma lista de campos [tamanho u16][campo u32][valor] até o campo LAST.
    def cards(bytes)
      reader = ByteReader.new(bytes)
      finish = reader.u32 + 4
      cards = []
      cards << card(reader) while reader.offset < finish
      cards
    end

    def card(reader)
      size = reader.u16
      return if size.zero?

      card = {}
      loop do
        field = reader.u32
        break if field == LAST

        value = reader.bytes(size - 4)
        case field
        when CODE then card[:code] = value.unpack1("L<")
        when POSITION then card[:position] = value.unpack1("L<")
        when ATTACK then card[:atk] = value.unpack1("l<")
        when DEFENSE then card[:def] = value.unpack1("l<")
        when IS_PUBLIC then card[:public] = value.getbyte(0) == 1
        end
        size = reader.u16
      end
      card
    end

    # PV e quantas cartas há em cada lugar dos dois lados (o resto do buffer, que é a cadeia
    # e as zonas ocupadas, a tela tira das consultas por lugar).
    def field(bytes)
      reader = ByteReader.new(bytes)
      reader.u32 # opções do duelo
      Array.new(2) do
        lp = reader.u32
        # 7 zonas de monstro e 8 de magia/armadilha: 1 byte (ocupada ou não) e, se ocupada,
        # posição (u8) e matérias Xyz (u32).
        (7 + 8).times { reader.bytes(5) if reader.u8 == 1 }
        { lp:, deck: reader.u32, hand: reader.u32, grave: reader.u32, banished: reader.u32, extra: reader.u32 }.tap { reader.u32 }
      end
    end
  end
end
