require "digest"

module Duel
  # Duelo inteiro entre dois TestBots (um por lado; no Tag, o mesmo bot joga pelos dois
  # duelistas do lado), para os testes de contrato e as medições. O digest resume todas as
  # mensagens da engine: refazer o duelo pelo replay tem que dar o mesmo digest.
  class BotMatch
    MAX_RESPONSES = 3000

    # draws: [turno, lado, códigos] de cada compra (turno 0 = mão inicial).
    # questions: [turno, lado, descrição] de cada pergunta de sim ou não.
    Result = Data.define(:winner, :reason, :turns, :responses, :digest, :errors, :draws, :questions)

    # destiny: a resposta de cada lado ao Destiny Draw. O resto (starting_lp:,
    # destiny_draw:) vai para a Duel::Engine.
    def initialize(seed:, decks:, destiny: [ true, true ], **options)
      @seed = seed
      @decks = decks
      @destiny = destiny
      @options = options
    end

    def play
      engine = Engine.new(seed: @seed, decks: @decks, **@options).start
      bots = @destiny.map { |answer| TestBot.new(destiny: answer) }
      digest = Digest::SHA256.new
      responses = []
      draws = []
      questions = []
      turns = 0
      win = nil
      loop do
        messages = engine.advance
        messages.each do |message|
          digest << message.type.chr << message.payload
          bots.each { |bot| bot.observe(message) }
          turns += 1 if message.type == MessageParser::NEW_TURN
          draws << [ turns, *MessageParser.draw(message).values_at(:player, :cards) ] if message.type == MessageParser::DRAW
        end
        raise "resposta inválida depois de #{responses.size} respostas" if messages.any? { |message| message.type == MessageParser::RETRY }

        # A engine não para sozinha no fim: quem hospeda encerra ao ver a mensagem de vitória.
        win_message = messages.find { |message| message.type == MessageParser::WIN }
        win = MessageParser.win(win_message) if win_message
        break if win || engine.finished? || responses.size >= MAX_RESPONSES

        prompt = MessageParser.prompt(messages.last)
        questions << [ turns, prompt[:player], prompt[:description] ] if prompt[:type] == :select_yesno
        response = bots.fetch(prompt[:player]).answer(prompt)
        engine.respond(response)
        responses << response
      end
      Result.new(winner: win&.fetch(:player), reason: win&.fetch(:reason), turns:, responses:,
                 digest: digest.hexdigest, errors: engine.errors, draws:, questions:)
    ensure
      engine&.close
    end

    # Refaz o duelo só com as respostas gravadas e devolve o digest das mensagens.
    def replay(responses)
      engine = Engine.new(seed: @seed, decks: @decks, **@options).start
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
