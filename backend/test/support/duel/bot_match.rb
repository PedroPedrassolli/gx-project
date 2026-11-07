require "digest"

module Duel
  # Duelo inteiro entre dois TestBots, para os testes de contrato e as medições.
  # O digest resume todas as mensagens da engine: refazer o duelo pelo replay tem que
  # dar o mesmo digest.
  class BotMatch
    MAX_RESPONSES = 3000

    Result = Data.define(:winner, :reason, :turns, :responses, :digest, :errors)

    def initialize(seed:, decks:)
      @seed = seed
      @decks = decks
    end

    def play
      engine = Engine.new(seed: @seed, decks: @decks).start
      bots = [ TestBot.new, TestBot.new ]
      digest = Digest::SHA256.new
      responses = []
      turns = 0
      win = nil
      loop do
        messages = engine.advance
        messages.each do |message|
          digest << message.type.chr << message.payload
          bots.each { |bot| bot.observe(message) }
        end
        raise "resposta inválida depois de #{responses.size} respostas" if messages.any? { |message| message.type == MessageParser::RETRY }

        turns += messages.count { |message| message.type == MessageParser::NEW_TURN }
        # A engine não para sozinha no fim: quem hospeda encerra ao ver a mensagem de vitória.
        win_message = messages.find { |message| message.type == MessageParser::WIN }
        win = MessageParser.win(win_message) if win_message
        break if win || engine.finished? || responses.size >= MAX_RESPONSES

        prompt = MessageParser.prompt(messages.last)
        response = bots.fetch(prompt[:player]).answer(prompt)
        engine.respond(response)
        responses << response
      end
      Result.new(winner: win&.fetch(:player), reason: win&.fetch(:reason), turns:, responses:,
                 digest: digest.hexdigest, errors: engine.errors)
    ensure
      engine&.close
    end

    # Refaz o duelo só com as respostas gravadas e devolve o digest das mensagens.
    def replay(responses)
      engine = Engine.new(seed: @seed, decks: @decks).start
      digest = Digest::SHA256.new
      responses.each do |response|
        engine.advance.each { |message| digest << message.type.chr << message.payload }
        engine.respond(response)
      end
      engine.advance.each { |message| digest << message.type.chr << message.payload }
      digest.hexdigest
    ensure
      engine&.close
    end
  end
end
