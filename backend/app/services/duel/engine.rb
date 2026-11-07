module Duel
  # Um duelo vivo dentro da engine. Quem usa monta com semente e decks, chama #start e
  # depois alterna #advance (roda até a próxima pergunta) e #respond. No fim, #close.
  #
  # A engine não embaralha os decks no começo: a ordem das listas é a ordem do deck. Quem
  # cria a partida embaralha e guarda essa ordem, junto com a semente e as respostas
  # (é isso que permite refazer o duelo igualzinho no replay).
  class Engine
    class Error < StandardError; end

    MODE_MR1 = 853_760 # DUEL_MODE_MR1
    STATUS_END = 0
    STATUS_CONTINUE = 2
    LOCATION_DECK = 0x01
    LOCATION_EXTRA = 0x40
    POS_FACEDOWN_DEFENSE = 0x8
    LOG_ERROR = 0 # OCG_LOG_TYPE_ERROR
    MAX_ERRORS = 20

    class << self
      # Carregados uma vez por processo, no primeiro duelo.
      def cards = @cards ||= CardDatabase.default
      def scripts = @scripts ||= ScriptLibrary.default

      def finalizer(handle) = proc { Native.destroy_duel(handle) }
    end

    # Callbacks que a engine chama. São criados uma vez por processo e ficam em constantes
    # para o GC não recolher. Nenhuma exceção pode escapar daqui: ela atravessaria o
    # código C++ da engine.
    CARD_READER = FFI::Function.new(:void, %i[pointer uint32 pointer]) do |_payload, code, data|
      Engine.cards.fill(code, Native::CardData.new(data))
    rescue StandardError => error
      Rails.logger.error("engine: falha ao ler a carta #{code}: #{error.class}")
    end

    CARD_READER_DONE = FFI::Function.new(:void, %i[pointer pointer]) { |_payload, _data| nil }

    SCRIPT_READER = FFI::Function.new(:int, %i[pointer pointer string]) do |_payload, duel, name|
      content = Engine.scripts.read(name)
      content ? Native.load_script(duel, content, content.bytesize, name) : 0
    rescue StandardError => error
      Rails.logger.error("engine: falha ao ler o script #{name}: #{error.class}")
      0
    end

    LOG_HANDLER = FFI::Function.new(:void, %i[pointer string int]) do |_payload, text, type|
      Thread.current[:duel_engine]&.record_error(text) if type == LOG_ERROR
    end

    attr_reader :status, :errors

    def initialize(seed:, decks:, flags: MODE_MR1, starting_lp: 8000)
      @seed = seed
      @decks = decks
      @flags = flags
      @starting_lp = starting_lp
      @errors = []
    end

    def start
      handle = FFI::MemoryPointer.new(:pointer)
      result = Native.create_duel(handle, options)
      raise Error, "a engine recusou o duelo (código #{result})" unless result.zero?

      @handle = handle.read_pointer
      ObjectSpace.define_finalizer(self, self.class.finalizer(@handle))
      as_current do
        # A engine só carrega sozinha o script de cada carta; estes dois são a base de todos.
        %w[constant.lua utility.lua].each { |name| load_base_script(name) }
        add_cards
        Native.start_duel(@handle)
      end
      self
    end

    # Roda até a engine precisar de uma resposta ou o duelo acabar; devolve as mensagens.
    def advance
      messages = []
      as_current do
        loop do
          @status = Native.process(@handle)
          messages.concat(take_messages)
          break unless @status == STATUS_CONTINUE
        end
      end
      messages
    end

    def respond(bytes)
      Native.set_response(@handle, bytes, bytes.bytesize)
    end

    def finished? = @status == STATUS_END

    def close
      return unless @handle

      ObjectSpace.undefine_finalizer(self)
      Native.destroy_duel(@handle)
      @handle = nil
    end

    # Chamado pelo LOG_HANDLER. Guarda poucos erros: o suficiente para diagnosticar.
    def record_error(text)
      Rails.logger.warn("engine: #{text}")
      @errors << text if @errors.size < MAX_ERRORS
    end

    private

    # Os erros de script chegam por um callback global; isto diz a ele de qual duelo são.
    def as_current
      Thread.current[:duel_engine] = self
      yield
    ensure
      Thread.current[:duel_engine] = nil
    end

    def options
      Native::DuelOptions.new.tap do |options|
        @seed.each_with_index { |value, index| options[:seed][index] = value }
        options[:flags] = @flags
        %i[team1 team2].each do |team|
          options[team][:starting_lp] = @starting_lp
          options[team][:starting_draw_count] = 5
          options[team][:draw_count_per_turn] = 1
        end
        options[:card_reader] = CARD_READER
        options[:script_reader] = SCRIPT_READER
        options[:log_handler] = LOG_HANDLER
        options[:card_reader_done] = CARD_READER_DONE
      end
    end

    def load_base_script(name)
      content = Engine.scripts.read(name) or raise Error, "script #{name} não encontrado"
      loaded = Native.load_script(@handle, content, content.bytesize, name)
      raise Error, "a engine não carregou #{name}" unless loaded == 1
    end

    def add_cards
      @decks.each_with_index do |deck, team|
        deck.fetch(:main).each { |code| new_card(team, code, LOCATION_DECK) }
        deck.fetch(:extra, []).each { |code| new_card(team, code, LOCATION_EXTRA) }
      end
    end

    def new_card(team, code, location)
      info = Native::NewCardInfo.new
      info[:team] = team
      info[:duelist] = 0
      info[:code] = code
      info[:con] = team
      info[:loc] = location
      info[:seq] = 0
      info[:pos] = POS_FACEDOWN_DEFENSE
      Native.new_card(@handle, info)
    end

    def take_messages
      length = FFI::MemoryPointer.new(:uint32)
      pointer = Native.get_message(@handle, length)
      size = length.read_uint32
      size.zero? ? [] : MessageParser.split(pointer.read_bytes(size))
    end
  end
end
