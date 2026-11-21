require "test_helper"

class Bots::PlayerTest < ActiveSupport::TestCase
  # Cartas de verdade da engine: ATK/DEF e tipo vêm do banco de cartas dela.
  DARK_MAGICIAN = 46986414 # 2500/2100, nível 7
  BLUE_EYES = 89631139     # 3000/2500, nível 8
  MYSTIC_TOMATO = 83011277 # 1400/1100, nível 4
  STONE = 13039848         # Giant Soldier of Stone, 1300/2000, nível 3
  GEMINI_ELF = 69140098    # 1900/900, nível 4
  CYBER_DRAGON = 70095154  # 2100/1600, nível 5
  MIRROR_FORCE = 44095762  # armadilha
  SOLEMN = 41420027        # Contra-Armadilha
  POT_OF_GREED = 55144522  # magia
  MST = 5318639            # Magia Rápida
  DARK_HOLE = 53129443
  HEAVY_STORM = 19613556
  AXE = 40619825           # magia de equipamento

  def bot(skill: 3, random: FixedRandom.new(0.99)) = Bots::Player.new(team: 0, skill:, random:, codes: [ DARK_MAGICIAN ])

  def monster(code, atk:, defense: false, face_down: false, def_: 1000) = { face_down:, defense:, code:, atk:, def: def_ }

  def side(team, monsters: [], spells: [], field_spell: nil)
    { team:, lp: 8000, hand: [], monsters: monsters + [ nil ] * (5 - monsters.size), spells: spells + [ nil ] * (5 - spells.size), field_spell: }
  end

  def table(prompt, mine: side(0), theirs: side(1), phase: "main1", events: [], turn: 1)
    { turn:, phase:, prompt:, events:, sides: [ mine, theirs ] }
  end

  def card(code, location: 0x02, sequence: 0, controller: 0, **extra) = { code:, controller:, location:, sequence:, **extra }

  def idle(**lists)
    { type: "select_idlecmd", player: 0, summonable: [], spsummonable: [], repositionable: [], msetable: [], ssetable: [],
      activatable: [], to_bp: true, to_ep: true, can_shuffle: false }.merge(lists)
  end

  def battle(**lists) = { type: "select_battlecmd", player: 0, activatable: [], attackable: [], to_m2: true, to_ep: true }.merge(lists)

  describe "na fase principal" do
    it "invoca por Invocação-Especial antes de tudo" do
      prompt = idle(spsummonable: [ card(CYBER_DRAGON) ], summonable: [ card(GEMINI_ELF) ])

      _(bot.choose(table(prompt))).must_equal({ command: "spsummon", index: 0 })
    end

    it "ativa magia, mas guarda a armadilha para o turno do oponente" do
      _(bot.choose(table(idle(activatable: [ card(MIRROR_FORCE, location: 0x08), card(POT_OF_GREED) ])))).must_equal({ command: "activate", index: 1 })
      _(bot.choose(table(idle(activatable: [ card(MIRROR_FORCE, location: 0x08) ])))).must_equal({ command: "end" })
    end

    it "só ativa a carta perigosa quando vale a pena" do
      behind = side(1, monsters: [ monster(DARK_MAGICIAN, atk: 2500), monster(STONE, atk: 1300) ])
      even = side(1, monsters: [ monster(STONE, atk: 1300) ])
      mine = side(0, monsters: [ monster(GEMINI_ELF, atk: 1900) ])

      _(bot.choose(table(idle(activatable: [ card(DARK_HOLE) ]), mine:, theirs: behind))[:command]).must_equal "activate"
      _(bot.choose(table(idle(activatable: [ card(DARK_HOLE) ]), mine:, theirs: even))[:command]).must_equal "battle"
      _(bot.choose(table(idle(activatable: [ card(MST) ])))[:command]).must_equal "end"
      _(bot.choose(table(idle(activatable: [ card(MST) ]), theirs: side(1, spells: [ { face_down: true, defense: false } ])))[:command]).must_equal "activate"
      _(bot.choose(table(idle(activatable: [ card(HEAVY_STORM) ]), theirs: side(1, field_spell: { face_down: false, defense: false })))[:command]).must_equal "activate"
      _(bot.choose(table(idle(activatable: [ card(AXE) ])))[:command]).must_equal "end"
      _(bot.choose(table(idle(activatable: [ card(AXE) ]), mine:))[:command]).must_equal "activate"
    end

    it "ativa o mesmo efeito no máximo duas vezes por turno" do
      player = bot
      prompt = idle(activatable: [ card(POT_OF_GREED, description: 1) ], to_bp: false)

      _(3.times.map { player.choose(table(prompt))[:command] }).must_equal %w[activate activate end]
      _(player.choose(table(prompt, turn: 2))[:command]).must_equal "activate"
    end

    it "para de agir depois de muitas ações no turno" do
      player = bot
      prompt = idle(summonable: [ card(GEMINI_ELF) ], to_bp: false)

      _(16.times.map { player.choose(table(prompt))[:command] }.last(2)).must_equal %w[summon end]
    end

    it "invoca o mais forte, com Tributo só se fica mais forte" do
      prompt = idle(summonable: [ card(MYSTIC_TOMATO), card(DARK_MAGICIAN, sequence: 1), card(GEMINI_ELF, sequence: 2) ])
      strong = side(0, monsters: [ monster(BLUE_EYES, atk: 3000) ])

      _(bot.choose(table(prompt))).must_equal({ command: "summon", index: 1 })
      _(bot.choose(table(prompt, mine: strong))).must_equal({ command: "summon", index: 2 })
    end

    it "baixa o de mais DEF quando o mais forte perde para o monstro do oponente" do
      prompt = idle(summonable: [ card(GEMINI_ELF) ], msetable: [ card(GEMINI_ELF), card(STONE, sequence: 1), card(BLUE_EYES, sequence: 2) ])
      theirs = side(1, monsters: [ monster(DARK_MAGICIAN, atk: 2500) ])

      _(bot.choose(table(prompt, theirs:))).must_equal({ command: "mset", index: 1 })
      _(bot.choose(table(idle(summonable: [ card(GEMINI_ELF) ]), theirs:))).must_equal({ command: "summon", index: 0 })
    end

    it "baixa armadilha e Magia Rápida, não a magia normal" do
      _(bot.choose(table(idle(ssetable: [ card(POT_OF_GREED), card(MIRROR_FORCE, sequence: 1) ])))).must_equal({ command: "sset", index: 1 })
      _(bot.choose(table(idle(ssetable: [ card(POT_OF_GREED) ], to_bp: false)))).must_equal({ command: "end" })
    end

    it "muda de posição: para o ataque antes da batalha, para a defesa depois" do
      mine = side(0, monsters: [ monster(DARK_MAGICIAN, atk: 2500, defense: true), monster(MYSTIC_TOMATO, atk: 1400, def_: 1100), monster(STONE, atk: 1300, def_: 2000) ])
      theirs = side(1, monsters: [ monster(GEMINI_ELF, atk: 1900) ])
      prompt = idle(repositionable: [ card(DARK_MAGICIAN, location: 0x04), card(MYSTIC_TOMATO, location: 0x04, sequence: 1),
                                      card(STONE, location: 0x04, sequence: 2), card(BLUE_EYES, location: 0x04, sequence: 4) ])

      _(bot.choose(table(prompt, mine:, theirs:))).must_equal({ command: "reposition", index: 0 })
      _(bot.choose(table(prompt, mine:, theirs:, phase: "main2"))).must_equal({ command: "reposition", index: 2 })
    end

    it "vai para a batalha com monstro em ataque; senão, encerra; sem saída, escolhe ao acaso" do
      attacker = side(0, monsters: [ monster(GEMINI_ELF, atk: 1900) ])

      _(bot.choose(table(idle, mine: attacker))).must_equal({ command: "battle" })
      _(bot.choose(table(idle, mine: attacker, phase: "main2"))).must_equal({ command: "end" })
      _(bot.choose(table(idle(to_bp: false, to_ep: false, repositionable: [ card(GEMINI_ELF, location: 0x04) ]), mine: attacker)))
        .must_equal({ command: "reposition", index: 0 })
    end
  end

  describe "na batalha" do
    let(:mine) { side(0, monsters: [ monster(DARK_MAGICIAN, atk: 2500), monster(MYSTIC_TOMATO, atk: 1400) ]) }
    let(:attackers) { [ card(DARK_MAGICIAN, location: 0x04), card(MYSTIC_TOMATO, location: 0x04, sequence: 1) ] }

    it "ataca direto quando o oponente não tem monstro" do
      _(bot.choose(table(battle(attackable: attackers), mine:, phase: "battle"))).must_equal({ command: "attack", index: 0 })
    end

    it "ataca o que vence e escolhe esse alvo na pergunta seguinte" do
      player = bot
      theirs = side(1, monsters: [ monster(BLUE_EYES, atk: 3000), monster(GEMINI_ELF, atk: 1900), monster(STONE, atk: 1300, def_: 2000, defense: true) ])
      targets = [ card(BLUE_EYES, controller: 1, location: 0x04), card(GEMINI_ELF, controller: 1, location: 0x04, sequence: 1),
                  card(STONE, controller: 1, location: 0x04, sequence: 2) ]

      _(player.choose(table(battle(attackable: attackers), mine:, theirs:, phase: "battle"))).must_equal({ command: "attack", index: 0 })
      _(player.choose(table({ type: "select_card", player: 0, cancelable: false, min: 1, max: 1, hint: 549, cards: targets }, mine:, theirs:))).must_equal({ indexes: [ 1 ] })
    end

    it "sem plano, o alvo do ataque é o mais fraco" do
      targets = [ card(BLUE_EYES, controller: 1, location: 0x04), card(STONE, controller: 1, location: 0x04, sequence: 1) ]
      theirs = side(1, monsters: [ monster(BLUE_EYES, atk: 3000), monster(STONE, atk: 1300) ])

      _(bot.choose(table({ type: "select_card", player: 0, cancelable: false, min: 1, max: 1, hint: 549, cards: targets }, theirs:))).must_equal({ indexes: [ 1 ] })
    end

    it "arrisca carta virada só com atacante forte" do
      theirs = side(1, monsters: [ { face_down: true, defense: true } ])

      _(bot.choose(table(battle(attackable: attackers), mine:, theirs:, phase: "battle"))).must_equal({ command: "attack", index: 0 })
      _(bot.choose(table(battle(attackable: attackers.last(1)), mine:, theirs:, phase: "battle"))).must_equal({ command: "main2" })
    end

    it "sem ataque que valha, vai para a Principal 2, encerra ou, sem saída, ataca" do
      theirs = side(1, monsters: [ monster(BLUE_EYES, atk: 3000) ])

      _(bot.choose(table(battle(attackable: attackers), mine:, theirs:, phase: "battle"))).must_equal({ command: "main2" })
      _(bot.choose(table(battle(attackable: attackers, to_m2: false), mine:, theirs:, phase: "battle"))).must_equal({ command: "end" })
      _(bot.choose(table(battle(attackable: attackers, to_m2: false, to_ep: false), mine:, theirs:, phase: "battle"))).must_equal({ command: "attack", index: 0 })
    end
  end

  describe "nas escolhas de carta" do
    let(:mine) { side(0, monsters: [ monster(GEMINI_ELF, atk: 1900), monster(STONE, atk: 1300) ]) }
    let(:theirs) { side(1, monsters: [ monster(DARK_MAGICIAN, atk: 2500), { face_down: true, defense: true } ]) }
    let(:field) do
      [ card(GEMINI_ELF, location: 0x04), card(STONE, location: 0x04, sequence: 1),
        card(DARK_MAGICIAN, controller: 1, location: 0x04), card(0, controller: 1, location: 0x04, sequence: 1) ]
    end

    def pick(hint, cards, min: 1, **sides) = bot.choose(table({ type: "select_card", player: 0, cancelable: false, min:, max: 2, hint:, cards: }, **sides))

    it "destrói o melhor do oponente e, se tiver de ser seu, o pior" do
      _(pick(502, field, mine:, theirs:)).must_equal({ indexes: [ 2 ] })
      _(pick(502, field.first(2), mine:, theirs:)).must_equal({ indexes: [ 1 ] })
      _(pick(502, field.last(1), mine:, theirs:)).must_equal({ indexes: [ 0 ] })
    end

    it "para a mão ou para o campo, escolhe o melhor seu" do
      hand = [ card(POT_OF_GREED), card(BLUE_EYES, sequence: 1), card(MYSTIC_TOMATO, sequence: 2) ]

      _(pick(506, hand, min: 2)).must_equal({ indexes: [ 1, 2 ] })
    end

    it "uma por vez, a de melhor nota, até poder concluir" do
      prompt = { type: "select_unselect_card", player: 0, finishable: false, cancelable: false, min: 1, max: 1, hint: 502, selectable: field, unselectable: [] }

      _(bot.choose(table(prompt, mine:, theirs:))).must_equal({ index: 2 })
      _(bot.choose(table(prompt.merge(finishable: true), mine:, theirs:))).must_equal({ index: -1 })
      _(bot.choose(table(prompt.merge(selectable: []), mine:, theirs:))).must_equal({ index: -1 })
    end

    it "oferece como Tributo os mais fracos" do
      prompt = { type: "select_tribute", player: 0, cancelable: false, min: 2, max: 2,
                 cards: [ card(GEMINI_ELF, location: 0x04, release_param: 1), card(STONE, location: 0x04, sequence: 1, release_param: 1),
                          card(MYSTIC_TOMATO, location: 0x04, sequence: 2, release_param: 1) ] }
      monsters = side(0, monsters: [ monster(GEMINI_ELF, atk: 1900), monster(STONE, atk: 1300), monster(MYSTIC_TOMATO, atk: 1400) ])

      _(bot.choose(table(prompt, mine: monsters))).must_equal({ indexes: [ 1, 2 ] })
      _(bot(random: Random.new(1)).choose(table(prompt.merge(min: 4), mine: monsters))).must_equal({ cancel: true })
    end
  end

  describe "na corrente" do
    def chain(cards, **options) = { type: "select_chain", player: 0, spe_count: 0, forced: false, hint_timing: 0, hint_timing_other: 0, chains: cards }.merge(options)

    let(:traps) { [ card(SOLEMN, location: 0x08), card(MIRROR_FORCE, location: 0x08, sequence: 1) ] }
    let(:attack) { { type: "attack", id: 7, attacker: { controller: 1, location: 0x04, sequence: 0, position: 1 }, target: nil } }

    it "ativa o que é obrigatório e o próprio gatilho" do
      _(bot.choose(table(chain(traps, forced: true)))).must_equal({ index: 0 })
      _(bot.choose(table(chain(traps, spe_count: 1)))).must_equal({ index: 0 })
    end

    it "ativa a armadilha quando o oponente ataca ou invoca" do
      summon = { type: "summon", id: 8, kind: "normal", code: BLUE_EYES, controller: 1, location: 0x04, sequence: 0, position: 1 }

      _(bot.choose(table(chain(traps), events: [ attack ]))).must_equal({ index: 0 })
      _(bot.choose(table(chain(traps.last(1)), events: [ summon ]))).must_equal({ index: 0 })
    end

    it "responde à ativação do oponente só com Contra-Armadilha" do
      activation = { type: "chain", id: 9, code: POT_OF_GREED, controller: 1, location: 0x02, sequence: 0, position: 0 }

      _(bot.choose(table(chain(traps.reverse), events: [ activation ]))).must_equal({ index: 1 })
      _(bot.choose(table(chain(traps.last(1)), events: [ activation ]))).must_equal({ index: -1 })
    end

    it "deixa passar no próprio lance, depois que a corrente resolveu, sem lance e quando o nível falha" do
      mine = attack.merge(attacker: attack[:attacker].merge(controller: 0))

      _(bot.choose(table(chain(traps), events: [ mine ]))).must_equal({ index: -1 })
      _(bot.choose(table(chain(traps), events: [ attack, { type: "chain_solved", id: 10, link: 1 } ]))).must_equal({ index: -1 })
      _(bot.choose(table(chain(traps)))).must_equal({ index: -1 })
      _(bot(skill: 1, random: FixedRandom.new(0.7)).choose(table(chain(traps), events: [ attack ]))).must_equal({ index: -1 })
    end
  end

  describe "nas outras perguntas" do
    it "invoca em ataque quem vence, e em defesa quem perderia" do
      prompt = { type: "select_position", player: 0, code: STONE, positions: 0x1 | 0x4 }
      theirs = side(1, monsters: [ monster(GEMINI_ELF, atk: 1900) ])

      _(bot.choose(table(prompt, theirs:))).must_equal({ position: 0x4 })
      _(bot.choose(table(prompt))).must_equal({ position: 0x1 })
      _(bot.choose(table(prompt.merge(code: DARK_MAGICIAN), theirs:))).must_equal({ position: 0x1 })
      _(bot.choose(table(prompt.merge(positions: 0x2), theirs:))).must_equal({ position: 0x2 })
    end

    it "aceita o efeito, mantém a ordem e, no resto, escolhe ao acaso" do
      _(bot.choose(table({ type: "select_effectyn", player: 0, code: STONE }))).must_equal({ yes: true })
      _(bot.choose(table({ type: "select_yesno", player: 0, description: 31 }))).must_equal({ yes: true })
      _(bot.choose(table({ type: "sort_chain", player: 0, cards: [] }))).must_equal({})
      _(bot.choose(table({ type: "announce_number", player: 0, options: [ 3, 4 ] }))).must_equal({ index: 0 })
    end

    it "erra de propósito no nível mais fácil" do
      prompt = idle(summonable: [ card(MYSTIC_TOMATO), card(GEMINI_ELF, sequence: 1) ])

      _(bot(skill: 1, random: FixedRandom.new(0.1)).choose(table(prompt))).must_equal({ command: "summon", index: 0 })
      _(bot(skill: 1, random: FixedRandom.new(0.5)).choose(table(prompt))).must_equal({ command: "summon", index: 1 })
    end
  end
end
