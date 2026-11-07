module Duel
  # Transforma os bytes que a engine devolve em mensagens.
  # Cada mensagem vem como [tamanho u32][tipo u8][conteúdo]; o tamanho conta o tipo.
  # As perguntas (prompts) viram Hashes com os campos que a tela e o bot precisam.
  # O formato de cada uma está no playerop.cpp da engine fixada.
  module MessageParser
    Message = Data.define(:type, :payload)

    # Tipos de mensagem (MSG_* do ocgapi_constants.h) usados fora das perguntas.
    RETRY = 1
    WIN = 5
    NEW_TURN = 40
    DRAW = 90

    # As perguntas que a engine faz aos jogadores (lista fechada pelo header fixado).
    PROMPTS = {
      10 => :select_battlecmd, 11 => :select_idlecmd, 12 => :select_effectyn,
      13 => :select_yesno, 14 => :select_option, 15 => :select_card, 16 => :select_chain,
      18 => :select_place, 19 => :select_position, 20 => :select_tribute, 21 => :sort_chain,
      22 => :select_counter, 23 => :select_sum, 24 => :select_disfield, 25 => :sort_card,
      26 => :select_unselect_card, 132 => :rock_paper_scissors, 140 => :announce_race,
      141 => :announce_attrib, 142 => :announce_card, 143 => :announce_number
    }.freeze

    module_function

    def split(buffer)
      messages = []
      offset = 0
      while offset < buffer.bytesize
        size = buffer.unpack1("L<", offset:)
        messages << Message.new(type: buffer.getbyte(offset + 4), payload: buffer.byteslice(offset + 5, size - 1))
        offset += 4 + size
      end
      messages
    end

    # Nome da pergunta (ex.: :select_idlecmd) ou nil se a mensagem não for pergunta.
    def prompt_name(message) = PROMPTS[message.type]

    # A pergunta inteira: { type:, player:, ...campos }. Nil se não for pergunta.
    def prompt(message)
      name = prompt_name(message)
      return unless name

      reader = ByteReader.new(message.payload)
      { type: name, player: reader.u8 }.merge(PromptFields.public_send(name, reader))
    end

    # Quem venceu (2 = empate) e o motivo, como a engine informa.
    def win(message)
      reader = ByteReader.new(message.payload)
      { player: reader.u8, reason: reader.u8 }
    end

    # Compra: o lado e os códigos das cartas. A engine manda os códigos sempre; esconder a
    # mão do oponente é trabalho do servidor.
    def draw(message)
      reader = ByteReader.new(message.payload)
      player = reader.u8
      cards = Array.new(reader.u32) do
        code = reader.u32
        reader.u32 # posição
        code
      end
      { player:, cards: }
    end

    # Campos de cada pergunta, na ordem em que a engine escreve (depois do jogador).
    module PromptFields
      module_function

      # Carta com local e sequência de 4 bytes (a maioria das listas).
      def card_at(reader)
        { code: reader.u32, controller: reader.u8, location: reader.u8, sequence: reader.u32 }
      end

      # Mesma coisa, mas com a sequência num byte só (atacantes e reposicionáveis).
      def short_card_at(reader)
        { code: reader.u32, controller: reader.u8, location: reader.u8, sequence: reader.u8 }
      end

      def card_with_location(reader) = { code: reader.u32, **reader.location }

      def effect_at(reader) = { **card_at(reader), description: reader.u64, client_mode: reader.u8 }

      def select_idlecmd(reader)
        {
          summonable: reader.list { card_at(reader) },
          spsummonable: reader.list { card_at(reader) },
          repositionable: reader.list { short_card_at(reader) },
          msetable: reader.list { card_at(reader) },
          ssetable: reader.list { card_at(reader) },
          activatable: reader.list { effect_at(reader) },
          to_bp: reader.u8 == 1, to_ep: reader.u8 == 1, can_shuffle: reader.u8 == 1
        }
      end

      def select_battlecmd(reader)
        {
          activatable: reader.list { effect_at(reader) },
          attackable: reader.list { { **short_card_at(reader), direct: reader.u8 == 1 } },
          to_m2: reader.u8 == 1, to_ep: reader.u8 == 1
        }
      end

      def select_effectyn(reader) = { **card_with_location(reader), description: reader.u64 }
      def select_yesno(reader) = { description: reader.u64 }
      def select_option(reader) = { options: Array.new(reader.u8) { reader.u64 } }

      def select_card(reader)
        { cancelable: reader.u8 == 1, min: reader.u32, max: reader.u32,
          cards: reader.list { card_with_location(reader) } }
      end

      def select_unselect_card(reader)
        { finishable: reader.u8 == 1, cancelable: reader.u8 == 1, min: reader.u32, max: reader.u32,
          selectable: reader.list { card_with_location(reader) },
          unselectable: reader.list { card_with_location(reader) } }
      end

      def select_chain(reader)
        { spe_count: reader.u8, forced: reader.u8 == 1, hint_timing: reader.u32,
          hint_timing_other: reader.u32,
          chains: reader.list { { **card_with_location(reader), description: reader.u64, client_mode: reader.u8 } } }
      end

      # No "flag", bit ligado = zona que NÃO pode ser escolhida.
      def select_place(reader) = { count: reader.u8, flag: reader.u32 }
      def select_disfield(reader) = select_place(reader)

      def select_position(reader) = { code: reader.u32, positions: reader.u8 }

      def select_tribute(reader)
        { cancelable: reader.u8 == 1, min: reader.u32, max: reader.u32,
          cards: reader.list { { **card_at(reader), release_param: reader.u8 } } }
      end

      def select_counter(reader)
        { counter_type: reader.u16, count: reader.u16,
          cards: reader.list { { **short_card_at(reader), counters: reader.u16 } } }
      end

      def select_sum(reader)
        { select_max: reader.u8.zero?, acc: reader.u32, min: reader.u32, max: reader.u32,
          must: reader.list { { **card_with_location(reader), sum: reader.u32 } },
          cards: reader.list { { **card_with_location(reader), sum: reader.u32 } } }
      end

      def sort_card(reader)
        { cards: reader.list { { code: reader.u32, controller: reader.u8, location: reader.u32, sequence: reader.u32 } } }
      end

      def sort_chain(reader) = sort_card(reader)
      def rock_paper_scissors(_reader) = {}
      def announce_race(reader) = { count: reader.u8, available: reader.u64 }
      def announce_attrib(reader) = { count: reader.u8, available: reader.u32 }
      def announce_card(reader) = { opcodes: Array.new(reader.u8) { reader.u64 } }
      def announce_number(reader) = { options: Array.new(reader.u8) { reader.u64 } }
    end
  end
end
