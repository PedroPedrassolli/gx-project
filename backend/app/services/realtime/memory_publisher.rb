module Realtime
  # Guarda os eventos na memória, no lugar do Ably (desenvolvimento e CI).
  class MemoryPublisher
    Event = Data.define(:channel, :name, :data)

    def initialize
      @events = []
      @mutex = Mutex.new
    end

    def publish(user_id:, event:, data:)
      @mutex.synchronize { @events << Event.new(channel: Publisher.channel_for(user_id), name: event, data:) }
    end

    # Eventos que chegaram no canal do jogador, na ordem em que foram mandados.
    def events_for(user_id)
      channel = Publisher.channel_for(user_id)
      @mutex.synchronize { @events.select { |event| event.channel == channel } }
    end

    def clear
      @mutex.synchronize { @events.clear }
    end
  end
end
