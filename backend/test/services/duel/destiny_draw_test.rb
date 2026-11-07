require "test_helper"

# Teste de contrato do Destiny Draw (destiny_draw.lua), com a regra do jogo de referência: com
# PV até 4000 e o lado em apuros no campo, se a situação não virar até a segunda Fase de
# Compra, o duelista da vez pode comprar uma das cartas Destiny que marcou. Uma vez por
# duelo para cada lado, inclusive no Tag. Vem ligado por padrão.
class Duel::DestinyDrawTest < ActiveSupport::TestCase
  MONSTER_REBORN, PREMATURE_BURIAL, CALL_OF_THE_HAUNTED = 83764718, 70828912, 97077563
  MOKEY_MOKEY, LUSTER_DRAGON = 27288416, 11091375

  # O lado 0 não tem monstros: só magias que não dá para usar aqui (Monster Reborn sem
  # monstro no cemitério) e as cartas Destiny no fundo do deck, que só saem pela regra.
  # O lado 1 tem Mokey Mokey (ATK 300): ataca direto todo turno, e o lado 0 fica em apuros.
  let(:helpless) { { main: [ PREMATURE_BURIAL ] * 3 + [ MONSTER_REBORN ] * 37, destiny: [ PREMATURE_BURIAL ] } }
  let(:mokeys) { { main: [ MOKEY_MOKEY ] * 40 } }

  def play(decks, starting_lp: 4000, answer: true, **rules)
    Duel::BotMatch.new(seed: [ 1, 2, 3, 4 ], decks:, starting_lp:, destiny: [ answer, true ], **rules).play
  end

  # Turnos em que o lado 0 ouviu a pergunta do Destiny Draw.
  def asked(result)
    result.questions.select { |_, side, description| side.zero? && description == Duel::Engine::DESTINY_DRAW_QUESTION }.map(&:first)
  end

  # O que o lado 0 comprou em cada turno.
  def draws(result)
    result.draws.select { |turn, side, _| turn.positive? && side.zero? }.to_h { |turn, _, cards| [ turn, cards ] }
  end

  describe "no 1x1" do
    # Turno 3: primeira Fase de Compra em apuros. Turno 5: a segunda.
    it "pergunta na segunda Fase de Compra seguida em apuros, não na primeira" do
      assert_equal 5, asked(play([ helpless, mokeys ])).first
    end

    it "aceitando, a carta Destiny é a compra do turno" do
      assert_equal [ PREMATURE_BURIAL ], draws(play([ helpless, mokeys ]))[5]
    end

    it "só uma vez por duelo para cada lado, mesmo continuando em apuros" do
      assert_equal [ 5 ], asked(play([ helpless, mokeys ]))
    end

    it "recusar não gasta: a compra é a normal e a pergunta volta enquanto a situação não virar" do
      result = play([ helpless, mokeys ], answer: false)
      assert_equal [ [ 5, 7, 9, 11 ], [ MONSTER_REBORN ] ], [ asked(result), draws(result)[5] ]
    end

    it "com PV acima do limite, espera o PV chegar a 4000 e mais uma Fase de Compra" do
      assert_equal [ 15 ], asked(play([ helpless, mokeys ], starting_lp: 8000))
    end

    it "não pergunta quando o lado tem monstro mais forte que o do oponente" do
      strong = { main: [ PREMATURE_BURIAL ] * 3 + [ LUSTER_DRAGON ] * 37, destiny: [ PREMATURE_BURIAL ] }
      assert_empty asked(play([ strong, mokeys ]))
    end

    it "não pergunta com a regra desligada" do
      assert_empty asked(play([ helpless, mokeys ], destiny_draw: false))
    end

    it "o replay sorteia e compra igual" do
      match = Duel::BotMatch.new(seed: [ 1, 2, 3, 4 ], decks: [ helpless, mokeys ], starting_lp: 4000)
      result = match.play
      assert_equal result.digest, match.replay(result.responses)
    end
  end

  describe "no Tag" do
    # A2 marcou outra carta como Destiny. Ordem dos turnos do lado 0: A1 (1, 5, 9) e A2 (3, 7, 11).
    let(:partner) { { main: [ CALL_OF_THE_HAUNTED ] * 3 + [ MONSTER_REBORN ] * 37, destiny: [ CALL_OF_THE_HAUNTED ] } }

    it "usa as cartas Destiny do duelista da vez" do
      no_destiny = helpless.merge(destiny: [])
      result = play([ no_destiny, mokeys, partner, mokeys ])
      assert_equal [ [ 7 ], [ CALL_OF_THE_HAUNTED ] ], [ asked(result), draws(result)[7] ]
    end

    it "uma vez por lado: depois do A1, o A2 não ouve mais a pergunta" do
      assert_equal [ 5 ], asked(play([ helpless, mokeys, partner, mokeys ]))
    end

    it "recusando, a pergunta volta no turno do outro duelista do lado" do
      assert_equal [ 5, 7 ], asked(play([ helpless, mokeys, partner, mokeys ], answer: false)).first(2)
    end
  end
end
