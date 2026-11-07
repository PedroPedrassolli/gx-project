module Duel
  # Lê números little-endian de uma string binária, avançando a posição.
  # As mensagens da engine são sequências desses números.
  class ByteReader
    class TruncatedError < StandardError; end

    def initialize(bytes)
      @bytes = bytes
      @offset = 0
    end

    def u8 = take(1, "C")
    def u16 = take(2, "S<")
    def u32 = take(4, "L<")
    def i32 = take(4, "l<")
    def u64 = take(8, "Q<")

    # Posição de uma carta no formato loc_info da engine (10 bytes).
    def location
      { controller: u8, location: u8, sequence: u32, position: u32 }
    end

    # Lista com a quantidade (u32) na frente.
    def list
      Array.new(u32) { yield }
    end

    private

    def take(size, format)
      raise TruncatedError, "mensagem acabou antes do esperado" if @offset + size > @bytes.bytesize

      value = @bytes.unpack1(format, offset: @offset)
      @offset += size
      value
    end
  end
end
