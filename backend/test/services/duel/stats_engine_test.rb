require "test_helper"

# As estatísticas do duelo conferidas na engine de verdade, com o campo montado à mão
# (DuelPuzzle): cada teste faz uma jogada e olha o que a Duel::Stats contou. É aqui que se
# garante que a ordem e o formato das mensagens da engine são os que a conta espera.
class Duel::StatsEngineTest < ActiveSupport::TestCase
  # O puzzle contando as mensagens de cada jogada.
  class Counted < DuelPuzzle
    attr_reader :stats

    def initialize(cards)
      super
      @stats = Duel::Stats.new
    end

    def advance = super.tap { |messages| @stats.update(messages) }
  end

  FISSURE = 66_788_016 # Magia: destrói o monstro mais fraco do oponente
  JUST_DESSERTS = 24_068_492 # Armadilha: 500 de dano por monstro do oponente
  SEVEN_TOOLS = 3_819_470 # Armadilha de resposta: nega uma armadilha (custa 1000 PV)
  POLYMERIZATION = 24_094_653
  AVIAN = 21_844_576 # 1000 de ATK
  BURSTINATRIX = 58_932_615
  FLAME_WINGMAN = 35_809_262 # Fusão de Avian + Burstinatrix
  SUMMONED_SKULL = 70_781_052 # nível 6: pede 1 tributo
  DARK_MAGICIAN = 46_986_414 # 2500 de ATK
  BLUE_EYES = 89_631_139 # 3000 de ATK, nível 8
  RITUAL = 55_761_792 # Black Luster Ritual
  SOLDIER = 5_405_694 # Black Luster Soldier, nível 8
  CARD_DESTRUCTION = 72_892_473 # os dois descartam a mão e compram
  CHANGE_OF_HEART = 4_031_928
  BREAKER = 71_413_901 # ganha 1 marcador de magia na invocação e gasta para destruir
  Y_DRAGON = 511_002_852 # União: equipa no X-Head Cannon
  X_HEAD = 62_651_957
  TIME_WIZARD = 71_625_222 # joga a moeda; errou, é destruído e o dono sofre dano
  HAND = Duel::Query::HAND
  MZONE = Duel::Query::MONSTERS
  SZONE = Duel::Query::SPELLS
  EXTRA = Duel::Query::EXTRA
  UP = DuelPuzzle::FACE_UP_ATTACK
  DOWN = DuelPuzzle::FACE_DOWN_DEFENSE
  PASS = { index: -1 }.freeze

  before { Duel::Engine.any_instance.expects(:record_error).never }

  # Monta o campo, responde cada pergunta com a escolha da vez e devolve as contas dos times.
  # A escolha pode ser um bloco que recebe a pergunta (para achar o índice da carta).
  def play(cards, *choices)
    puzzle = Counted.new(cards).start
    prompt = puzzle.next_prompt
    choices.each do |choice|
      puzzle.choose(prompt, choice.respond_to?(:call) ? choice.call(prompt) : choice)
      prompt = puzzle.next_prompt
    end
    [ puzzle.stats.team(0), puzzle.stats.team(1) ]
  end

  def index_of(list, code) = list.index { |card| card[:code] == code }
  def activate(code) = ->(prompt) { { command: "activate", index: index_of(prompt[:activatable], code) } }
  def summon(code) = ->(prompt) { { command: "summon", index: index_of(prompt[:summonable], code) } }
  def chain(code) = ->(prompt) { { index: index_of(prompt[:chains], code) } }
  def first_card = { indexes: [ 0 ] }

  it "magia ativada da mão ou baixada conta uma vez, e a carta do oponente destruída por efeito" do
    [ [ HAND, DOWN ], [ SZONE, DOWN ] ].each do |location, position|
      mine, = play([ [ 0, FISSURE, location, 0, position ], [ 1, BLUE_EYES, MZONE, 0, UP ] ], activate(FISSURE))

      assert_equal [ 1, 1, 1, [ FISSURE ] ], mine.values_at("spells", "effect_destroyed", "effect_destroyed_monsters", "used")
    end
  end

  it "armadilha: o dano de efeito é de quem ativou, e a negada não conta como usada" do
    mine, theirs = play([ [ 0, JUST_DESSERTS, SZONE, 0, DOWN ], [ 1, BLUE_EYES, MZONE, 0, UP ] ], chain(JUST_DESSERTS))
    assert_equal [ 1, 500, 500, [ JUST_DESSERTS ] ], mine.values_at("traps", "effect_damage", "max_hit", "used")
    assert_equal 500, theirs["damage_taken"]

    mine, theirs = play([ [ 0, JUST_DESSERTS, SZONE, 0, DOWN ], [ 1, BLUE_EYES, MZONE, 0, UP ], [ 1, SEVEN_TOOLS, SZONE, 0, DOWN ] ],
                        chain(JUST_DESSERTS), chain(SEVEN_TOOLS))
    assert_equal [ 1, nil, nil, 2 ], mine.values_at("traps", "used", "effect_damage", "max_chain")
    assert_equal [ 1, 1, 2, [ SEVEN_TOOLS ], 1000 ], theirs.values_at("traps", "negations", "max_chain", "used", "max_lp_deficit")
  end

  it "Invocação-Tributo, de Fusão e de Ritual" do
    mine, = play([ [ 0, SUMMONED_SKULL, HAND, 0, DOWN ], [ 0, DARK_MAGICIAN, MZONE, 0, UP ] ], summon(SUMMONED_SKULL), first_card)
    assert_equal [ 1, 1, 1, [ SUMMONED_SKULL ] ], mine.values_at("normal_summons", "tribute_summons", "tributes", "summoned")

    mine, = play([ [ 0, POLYMERIZATION, HAND, 0, DOWN ], [ 0, AVIAN, HAND, 0, DOWN ], [ 0, BURSTINATRIX, HAND, 0, DOWN ],
                   [ 0, FLAME_WINGMAN, EXTRA, 0, DOWN ] ], activate(POLYMERIZATION), first_card, { index: 0 }, { index: 0 }, { position: UP })
    assert_equal [ 1, 1, 1, nil ], mine.values_at("spells", "special_summons", "fusion_summons", "ritual_summons")

    mine, = play([ [ 0, RITUAL, HAND, 0, DOWN ], [ 0, SOLDIER, HAND, 0, DOWN ], [ 0, BLUE_EYES, HAND, 0, DOWN ] ],
                 activate(RITUAL), first_card, first_card, { position: UP })
    assert_equal [ 1, 1, nil, 1 ], mine.values_at("special_summons", "ritual_summons", "fusion_summons", "tributes")
  end

  it "batalha: ataque direto, e o dano refletido de quem atacou um monstro mais forte" do
    attack = [ { command: "end" }, { command: "battle" }, { command: "attack", index: 0 } ]
    mine, theirs = play([ [ 1, BLUE_EYES, MZONE, 1, UP ] ], *attack)
    assert_equal [ 3000, 3000, 3000, 3000, 3000 ], theirs.values_at("battle_damage", "direct_damage", "max_attack_damage", "max_atk", "max_turn_damage")
    assert_equal [ 3000, 3000 ], mine.values_at("damage_taken", "max_lp_deficit")

    mine, theirs = play([ [ 0, DARK_MAGICIAN, MZONE, 0, UP ], [ 1, AVIAN, MZONE, 0, UP ] ], *attack, first_card)
    assert_equal [ 1500, 1500, 1500, 1, 2500, nil ], mine.values_at("battle_damage", "reflected_damage", "max_reflected", "battle_destroyed", "max_atk", "max_attack_damage")
    assert_equal [ 1500, nil ], theirs.values_at("damage_taken", "battle_damage")
  end

  it "descartar a mão do oponente e tomar o controle de um monstro" do
    mine, theirs = play([ [ 0, CARD_DESTRUCTION, HAND, 0, DOWN ] ], activate(CARD_DESTRUCTION))
    assert_equal [ 5, nil ], [ mine["hand_discards"], theirs["hand_discards"] ]

    mine, = play([ [ 0, CHANGE_OF_HEART, HAND, 0, DOWN ], [ 1, BLUE_EYES, MZONE, 1, UP ] ], activate(CHANGE_OF_HEART), first_card)
    assert_equal 1, mine["controls_taken"]
  end

  it "marcadores de magia postos e gastos, e a União equipada" do
    mine, = play([ [ 0, BREAKER, HAND, 0, DOWN ], [ 1, JUST_DESSERTS, SZONE, 0, DOWN ] ], summon(BREAKER), PASS, { index: 0 }, first_card)
    assert_equal [ 1, 1 ], mine.values_at("spell_counters_added", "spell_counters_used")

    mine, = play([ [ 0, Y_DRAGON, HAND, 0, DOWN ], [ 0, X_HEAD, MZONE, 0, UP ] ], summon(Y_DRAGON), PASS, activate(Y_DRAGON), first_card)
    assert_equal [ 1, 1 ], mine.values_at("union_equips", "unions")
  end

  it "a moeda: quem errou não tem sequência, e o dano do próprio efeito não é de ninguém" do
    mine, theirs = play([ [ 0, TIME_WIZARD, MZONE, 0, UP ], [ 1, BLUE_EYES, MZONE, 1, UP ] ], activate(TIME_WIZARD), { index: 0 })

    assert_equal [ 0, 250, nil ], mine.values_at("coin_streak", "damage_taken", "effect_destroyed")
    assert_nil theirs["effect_damage"]
  end
end
