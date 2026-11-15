# Um duelo montado à mão para testar uma regra, como os puzzles do YGOPro: algumas cartas já
# começam na mão ou no campo, na posição pedida. É a engine de verdade; só muda o começo.
class DuelPuzzle < Duel::Engine
  # Monstro Normal do pool, só para encher os decks.
  FILLER = 732_302 # Temple of Skulls
  FACE_UP_ATTACK = 0x1
  FACE_DOWN_DEFENSE = 0x8

  # cards: [time, código, local, zona, posição] de cada carta que começa fora do deck.
  def initialize(cards)
    @puzzle = cards
    super(seed: [ 1, 2, 3, 4 ], decks: Array.new(2) { { main: [ FILLER ] * 40, extra: [] } }, destiny_draw: false)
  end

  # Roda até a próxima pergunta para um jogador. A cadeia sem opção e a zona da carta vão
  # sozinhas, como na partida (Matches::Game).
  def next_prompt
    loop do
      prompt = advance.filter_map { |message| Duel::MessageParser.prompt(message) }.last
      automatic = Matches::AutoPlace.pick(prompt) if prompt&.dig(:type) == :select_place
      automatic = Matches::Game::PASS if prompt&.dig(:type) == :select_chain && prompt[:chains].empty? && !prompt[:forced]
      return prompt unless automatic

      respond(automatic)
    end
  end

  # A escolha como a tela manda (o JSON); o Duel::ResponseEncoder monta os bytes.
  def choose(prompt, choice)
    respond(Duel::ResponseEncoder.encode(prompt[:type], choice))
  end

  private

  def add_cards
    super
    @puzzle.each do |team, code, location, sequence, position|
      info = Duel::Native::NewCardInfo.new
      info[:team] = team
      info[:duelist] = 0
      info[:code] = code
      info[:con] = team
      info[:loc] = location
      info[:seq] = sequence
      info[:pos] = position
      Duel::Native.new_card(@handle, info)
    end
  end
end
