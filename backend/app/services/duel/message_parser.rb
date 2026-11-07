module Duel
  # Transforma os bytes que a engine devolve em mensagens.
  # Cada mensagem vem como [tamanho u32][tipo u8][conteúdo]; o tamanho conta o tipo.
  module MessageParser
    Message = Data.define(:type, :payload)

    # Tipos de mensagem (MSG_* do ocgapi_constants.h) usados fora das perguntas.
    RETRY = 1
    WIN = 5
    NEW_TURN = 40

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

    # Quem venceu (2 = empate) e o motivo, como a engine informa.
    def win(message)
      reader = ByteReader.new(message.payload)
      { player: reader.u8, reason: reader.u8 }
    end
  end
end
