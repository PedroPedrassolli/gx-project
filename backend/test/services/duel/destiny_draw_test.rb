require "test_helper"

# Teste de contrato do Destiny Draw (destiny_draw.lua), com as regras da série Tag Force:
# com PV abaixo de 4000 e perdendo no campo, o duelista da vez pode pôr no topo do deck uma
# das cartas Destiny que marcou. Uma vez por duelo para cada lado, inclusive no Tag.
class Duel::DestinyDrawTest < ActiveSupport::TestCase
  MOKEY_MOKEY, PETIT_MOTH, MYSTICAL_ELF, LUSTER_DRAGON = 27288416, 58192742, 15025844, 11091375
  DARK_MAGICIAN, WARWOLF = 46986414, 69247929

  # O lado 0 tem monstros fracos (ATK 300) e as cartas Destiny no fundo do deck: elas só
  # saem pela regra. O lado 1 tem Mystical Elf (ATK 800) e ganha os combates.
  let(:weak) { { main: [ DARK_MAGICIAN ] * 3 + [ MOKEY_MOKEY ] * 37, destiny: [ DARK_MAGICIAN ] } }
  let(:elves) { { main: [ MYSTICAL_ELF ] * 40 } }

  def play(decks, starting_lp: 3000, destiny_draw: true, answer: true)
    Duel::BotMatch.new(seed: [ 1, 2, 3, 4 ], decks:, starting_lp:, destiny_draw:, destiny: [ answer, true ]).play
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
    it "pergunta no começo da Fase de Compra do lado que está perdendo" do
      assert_equal 3, asked(play([ weak, elves ])).first
    end

    it "aceitando, a carta Destiny vai para o topo e é a compra do turno" do
      assert_equal [ DARK_MAGICIAN ], draws(play([ weak, elves ]))[3]
    end

    it "só uma vez por duelo para cada lado" do
      assert_equal [ 3 ], asked(play([ weak, elves ]))
    end

    it "recusar não gasta: a compra é a normal e a pergunta volta no próximo turno do lado" do
      result = play([ weak, elves ], answer: false)
      assert_equal [ [ 3, 5 ], [ MOKEY_MOKEY ] ], [ asked(result), draws(result)[3] ]
    end

    it "com PV acima do limite, só pergunta quando o PV cai abaixo de 4000 (turno 7)" do
      assert_equal [ 7 ], asked(play([ weak, elves ], starting_lp: 8000))
    end

    it "não pergunta quando o lado tem monstro mais forte que o do oponente" do
      strong = { main: [ DARK_MAGICIAN ] * 3 + [ LUSTER_DRAGON ] * 37, destiny: [ DARK_MAGICIAN ] }
      assert_empty asked(play([ strong, elves ]))
    end

    it "não pergunta com a regra desligada" do
      assert_empty asked(play([ weak, elves ], destiny_draw: false))
    end

    it "o replay sorteia e compra igual" do
      match = Duel::BotMatch.new(seed: [ 1, 2, 3, 4 ], decks: [ weak, elves ], starting_lp: 3000, destiny_draw: true)
      result = match.play
      assert_equal result.digest, match.replay(result.responses)
    end
  end

  describe "no Tag" do
    # A2 marcou outra carta como Destiny: a regra usa a lista do duelista da vez.
    let(:partner) { { main: [ WARWOLF ] * 3 + [ PETIT_MOTH ] * 37, destiny: [ WARWOLF ] } }
    let(:decks) { [ weak, elves, partner, elves ] }

    it "usa as cartas Destiny do duelista da vez (A2, no turno 3)" do
      assert_equal [ WARWOLF ], draws(play(decks))[3]
    end

    it "uma vez por lado: depois do A2, o A1 não ouve mais a pergunta" do
      assert_equal [ 3 ], asked(play(decks))
    end

    it "recusando, a pergunta volta no turno do outro duelista do lado" do
      assert_equal [ 3, 5 ], asked(play(decks, answer: false))
    end
  end
end
