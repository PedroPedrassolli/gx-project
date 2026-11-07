module Duel
  # Engines vivas guardadas por duelo, no máximo `limit`: quando passa, sai a usada há mais
  # tempo (LRU). Quem usa tira a engine do cache (#take) e devolve depois (#put), então duas
  # requisições nunca mexem na mesma engine ao mesmo tempo.
  #
  # A versão diz em que ponto do duelo a engine está (Duel::Session usa um hash das
  # respostas). Engine em outra versão não serve mais: é fechada e o duelo é refeito.
  class EngineCache
    Entry = Data.define(:version, :engine)

    def initialize(limit)
      @limit = limit
      # O Hash guarda a ordem de entrada: a primeira é a usada há mais tempo.
      @entries = {}
      @mutex = Mutex.new
    end

    def take(id, version)
      entry = @mutex.synchronize { @entries.delete(id) }
      return entry.engine if entry&.version == version

      entry&.engine&.close
      nil
    end

    def put(id, version, engine)
      removed = @mutex.synchronize do
        replaced = @entries.delete(id)
        @entries[id] = Entry.new(version:, engine:)
        oldest = @entries.shift.last if @entries.size > @limit
        [ replaced, oldest ].compact.reject { |entry| entry.engine.equal?(engine) }
      end
      # Fecha fora do mutex: liberar a engine leva um tempinho e ninguém precisa esperar.
      removed.each { |entry| entry.engine.close }
    end

    def size
      @mutex.synchronize { @entries.size }
    end
  end
end
