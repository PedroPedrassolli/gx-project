module Economy
  # Os 104 desafios do jogo de referência (escopo 3.5; a lista original está em
  # db/seeds/jogo/desafios.yml): o texto em português e a condição de cada um, conferida no fim
  # do duelo com o que a Duel::Stats contou e com o deck que o jogador usou. Não lê banco.
  #
  # Decisões (ADR 0005): "vencer" é vencer na engine (desistência e tempo não concluem
  # desafio); "deck" é o Deck Principal, a não ser quando o desafio fala do Extra; "só com
  # monstros de..." pede pelo menos um monstro; e o deck de 80 cartas do original virou o de
  # 60, que é o máximo aqui. Três ficam sem condição (nil): os dois de Match, que nem aparecem,
  # porque não há melhor de 3 (GXP-125), e o da trava de Yata-Garasu, que a fonte não diz como
  # o jogo reconhece.
  module Challenges
    # O que se sabe do duelo de um jogador. counts: as contas do time (Duel::Stats#team);
    # summoned, used e finisher: nomes de cartas; main e extra: as cartas do deck (Card), com
    # as cópias; restricted: os ids das cartas que estão na banlist.
    Facts = Struct.new(:won, :draw, :turns, :opponent_turn, :win_reason, :counts, :summoned, :used, :finisher, :main, :extra,
                       :restricted, keyword_init: true) do
      def count(name) = counts.fetch(name, 0)
      def monsters = main.select { |card| card.card_type == "Monster" }
      def deck = main + extra
    end

    XYZ_SERIES = [ "X-Head Cannon", "Y-Dragon Head", "Z-Metal Tank", "XY-Dragon Cannon", "XZ-Tank Cannon", "YZ-Tank Dragon",
                   "XYZ-Dragon Cannon" ].freeze
    SACRED_BEASTS = [ "Uria, Lord of Searing Flames", "Hamon, Lord of Striking Thunder", "Raviel, Lord of Phantasms" ].freeze
    # 1 a 24: chegar a um número num duelo, ganhando ou não. [conta, mínimo, texto]
    COUNTS = [
      [ "battle_damage", 10_000, "Causar 10.000 ou mais de dano de batalha num duelo" ],
      [ "reflected_damage", 4_000, "Devolver 4.000 ou mais de dano de batalha ao oponente que atacou" ],
      [ "direct_damage", 20_000, "Causar 20.000 ou mais de dano com ataques diretos num duelo" ],
      [ "damage", 50_000, "Causar 50.000 ou mais de dano num duelo" ],
      [ "battle_destroyed", 20, "Destruir 20 monstros do oponente em batalha num duelo" ],
      [ "effect_destroyed_monsters", 30, "Destruir 30 monstros do oponente com efeitos num duelo" ],
      [ "banished_monsters", 10, "Remover do jogo 10 monstros do oponente com efeitos num duelo" ],
      [ "normal_summons", 10, "Fazer 10 Invocações-Normal num duelo" ],
      [ "flip_summons", 10, "Fazer 10 Invocações-Virada num duelo" ],
      [ "fusion_summons", 10, "Fazer 10 Invocações-Fusão num duelo" ],
      [ "ritual_summons", 10, "Fazer 10 Invocações-Ritual num duelo" ],
      [ "special_summons", 20, "Fazer 20 Invocações-Especiais num duelo" ],
      [ "tokens", 15, "Invocar 15 fichas num duelo" ],
      [ "union_equips", 5, "Equipar 5 monstros União num duelo" ],
      [ "toon_direct_damage", 8_000, "Causar 8.000 de dano com ataques diretos de monstros Toon" ],
      [ "spells", 20, "Ativar magias 20 vezes num duelo" ],
      [ "quick_spells_on_opponent_turn", 10, "Ativar magias rápidas 10 vezes no turno do oponente" ],
      [ "traps", 10, "Ativar 10 armadilhas num duelo" ],
      [ "negations", 10, "Negar 10 vezes cartas, efeitos ou ataques do oponente num duelo" ],
      [ "controls_taken", 10, "Tomar o controle de monstros do oponente 10 vezes num duelo" ],
      [ "max_chain", 5, "Formar uma corrente de 5 elos" ],
      [ "spell_counters_used", 10, "Usar 10 marcadores de magia num duelo" ],
      [ "hand_discards", 20, "Fazer o oponente descartar 20 cartas da mão num duelo" ],
      [ "recovered", 20_000, "Recuperar 20.000 PV ou mais num duelo" ]
    ].freeze
    # 25 a 54: resultados e vitórias. [texto, condição] (a condição das vitórias só é olhada
    # para quem venceu; nil é o desafio que ainda não dá para concluir).
    RESULTS = [
      [ "Vencer uma partida melhor de três", nil ],
      [ "Empatar um duelo", ->(duel) { duel.draw } ]
    ].freeze
    WINS = [
      [ "Vencer sem sofrer dano", ->(duel) { duel.count("damage_taken").zero? } ],
      [ "Causar 8.000 ou mais de dano num turno e vencer", ->(duel) { duel.count("max_turn_damage") >= 8_000 } ],
      [ "Causar 8.000 ou mais de dano com um só ataque ou efeito e vencer", ->(duel) { duel.count("max_hit") >= 8_000 } ],
      [ "Vencer porque o oponente ficou sem cartas para comprar", ->(duel) { duel.win_reason == BonusCalculator::DECK_OUT } ],
      [ "Vencer em até 7 turnos", ->(duel) { duel.turns <= 7 } ],
      [ "Vencer em até 5 turnos", ->(duel) { duel.turns <= 5 } ],
      [ "Vencer em até 3 turnos", ->(duel) { duel.turns <= 3 } ],
      [ "Vencer no turno do oponente", ->(duel) { duel.opponent_turn } ],
      [ "Vencer com Exodia", ->(duel) { duel.win_reason == 0x10 } ],
      [ "Vencer com a Contagem Final", ->(duel) { duel.win_reason == 0x11 } ],
      [ "Vencer com o Quadro do Destino", ->(duel) { duel.win_reason == 0x15 } ],
      [ "Vencer a partida inteira com o efeito de uma carta", nil ],
      [ "Vencer com a trava de Yata-Garasu", nil ],
      [ "Invocar todas as cartas da série XYZ e vencer", ->(duel) { (XYZ_SERIES - duel.summoned).empty? } ],
      [ "Invocar VWXYZ-Dragon Catapult Cannon e vencer", ->(duel) { duel.summoned.include?("VWXYZ-Dragon Catapult Cannon") } ],
      [ "Invocar Uria, Lord of Searing Flames e vencer", ->(duel) { duel.summoned.include?(SACRED_BEASTS[0]) } ],
      [ "Invocar Hamon, Lord of Striking Thunder e vencer", ->(duel) { duel.summoned.include?(SACRED_BEASTS[1]) } ],
      [ "Invocar Raviel, Lord of Phantasms e vencer", ->(duel) { duel.summoned.include?(SACRED_BEASTS[2]) } ],
      [ "Invocar as três Bestas Sagradas e vencer", ->(duel) { (SACRED_BEASTS - duel.summoned).empty? } ],
      [ "Usar Ojama Delta Hurricane!! e vencer", ->(duel) { duel.used.include?("Ojama Delta Hurricane!!") } ],
      [ "Usar Huge Revolution e vencer", ->(duel) { duel.used.include?("Huge Revolution") } ],
      [ "Invocar Perfectly Ultimate Great Moth e vencer", ->(duel) { duel.summoned.include?("Perfectly Ultimate Great Moth") } ],
      [ "Invocar Gate Guardian e vencer", ->(duel) { duel.summoned.include?("Gate Guardian") } ],
      [ "Invocar Valkyrion the Magna Warrior e vencer", ->(duel) { duel.summoned.include?("Valkyrion the Magna Warrior") } ],
      [ "Invocar Dark Sage e vencer", ->(duel) { duel.summoned.include?("Dark Sage") } ],
      [ "Usar Dark Scorpion Combination e vencer", ->(duel) { duel.used.include?("Dark Scorpion Combination") } ],
      [ "Usar Dark Scorpion Retreat e vencer", ->(duel) { duel.used.include?("Dark Scorpion Retreat") } ],
      [ "Vencer com o golpe final de Skull Servant", ->(duel) { duel.finisher == BonusCalculator::SKULL_SERVANT } ]
    ].freeze
    # 55 a 62: vencer com um deck sem certos monstros. [texto, o monstro que não pode ter]
    WITHOUT = [
      [ "sem monstros de Efeito", ->(card) { card.monster_types.include?("Effect") } ],
      [ "sem monstros de nível 4 ou menos", ->(card) { card.level.to_i <= 4 } ],
      [ "sem monstros de nível 5 ou mais", ->(card) { card.level.to_i >= 5 } ],
      [ "sem monstros de nível 2 ou mais", ->(card) { card.level.to_i >= 2 } ],
      nil, # 59: monstros de todos os níveis (em DECKS)
      [ "sem monstros com 1.500 de ATK ou menos", ->(card) { card.attack.to_i <= 1_500 } ],
      [ "sem monstros com 1.500 de ATK ou mais", ->(card) { card.attack.to_i >= 1_500 } ],
      [ "sem monstros com 1 de ATK ou mais", ->(card) { card.attack.to_i >= 1 } ]
    ].freeze
    # 63 a 92: vencer com um deck em que todo monstro é de um jeito. [texto, o monstro que vale]
    ATTRIBUTES = { "LIGHT" => "LUZ", "DARK" => "TREVAS", "WATER" => "ÁGUA", "FIRE" => "FOGO", "EARTH" => "TERRA", "WIND" => "VENTO" }.freeze
    RACES = { "Dragon" => "Dragão", "Zombie" => "Zumbi", "Fiend" => "Demônio", "Pyro" => "Piro", "Sea Serpent" => "Serpente Marinha",
              "Rock" => "Rocha", "Machine" => "Máquina", "Fish" => "Peixe", "Dinosaur" => "Dinossauro", "Insect" => "Inseto",
              "Beast" => "Besta", "Beast-Warrior" => "Besta-Guerreira", "Plant" => "Planta", "Aqua" => "Aqua", "Warrior" => "Guerreiro",
              "Winged Beast" => "Besta Alada", "Fairy" => "Fada", "Spellcaster" => "Mago", "Thunder" => "Trovão", "Reptile" => "Réptil" }.freeze
    ONLY = [
      *ATTRIBUTES.map { |attribute, name| [ "só com monstros de #{name}", ->(card) { card.card_attribute == attribute } ] },
      *RACES.map { |race, name| [ "só com monstros do tipo #{name}", ->(card) { card.race == race } ] },
      [ "só com monstros com \"LV\" no nome", ->(card) { card.name.include?("LV") } ],
      [ "só com monstros \"Elemental HERO\"", ->(card) { card.name.downcase.start_with?("elemental hero") } ],
      [ "só com monstros Espírito", ->(card) { card.monster_types.include?("Spirit") } ],
      [ "só com monstros Toon", ->(card) { card.monster_types.include?("Toon") } ]
    ].freeze
    LEVELS = (1..12).to_a.freeze
    MAX_DECK = 60
    # 93 a 103: o deck inteiro e o que o jogador não fez. [texto, condição]
    DECKS = [
      [ "Vencer com um deck sem monstros no Deck Principal", ->(duel) { duel.monsters.empty? } ],
      [ "Vencer com um deck sem monstros, nem no Extra", ->(duel) { duel.monsters.empty? && duel.extra.empty? } ],
      [ "Vencer com um deck sem armadilhas", ->(duel) { duel.main.none? { |card| card.card_type == "Trap" } } ],
      [ "Vencer com um deck sem magias", ->(duel) { duel.main.none? { |card| card.card_type == "Spell" } } ],
      [ "Vencer com um deck sem magias nem armadilhas", ->(duel) { duel.main.size == duel.monsters.size } ],
      [ "Vencer com um deck de #{MAX_DECK} cartas", ->(duel) { duel.main.size == MAX_DECK } ],
      [ "Vencer com um deck sem cartas proibidas, limitadas ou semilimitadas", ->(duel) { duel.deck.none? { |card| duel.restricted.include?(card.id) } } ],
      [ "Vencer com um deck com só uma cópia de cada carta", ->(duel) { duel.deck.uniq.size == duel.deck.size } ],
      [ "Vencer sem oferecer nenhum monstro como tributo", ->(duel) { duel.count("tributes").zero? } ],
      [ "Vencer sem Invocação-Especial", ->(duel) { duel.count("special_summons").zero? } ],
      [ "Vencer sem Invocação-Normal", ->(duel) { duel.count("normal_summons").zero? } ]
    ].freeze
    ALL_LEVELS = [ "Vencer com um deck com monstros de todos os níveis (1 a 12)", ->(duel) { (LEVELS - duel.monsters.map(&:level)).empty? } ].freeze
    LUCK = [ "Acertar a moeda 10 vezes seguidas", ->(duel) { duel.count("coin_streak") >= 10 } ].freeze

    # Todos, na ordem do jogo: { número, texto, quando vale (:always ou :win) e a condição }.
    LIST = [
      *COUNTS.map { |name, minimum, label| [ label, :always, ->(duel) { duel.count(name) >= minimum } ] },
      *RESULTS.map { |label, check| [ label, :always, check ] },
      *WINS.map { |label, check| [ label, :win, check ] },
      *WITHOUT.map { |label, banned| label ? [ "Vencer com um deck #{label}", :win, ->(duel) { duel.monsters.none?(&banned) } ] : [ ALL_LEVELS[0], :win, ALL_LEVELS[1] ] },
      *ONLY.map { |label, wanted| [ "Vencer com um deck #{label}", :win, ->(duel) { duel.monsters.any? && duel.monsters.all?(&wanted) } ] },
      *DECKS.map { |label, check| [ label, :win, check ] },
      [ LUCK[0], :always, LUCK[1] ]
    ].each_with_index.map { |(label, scope, check), index| { number: index + 1, label:, scope:, check: } }.freeze
    # Os que dá para concluir hoje (os pacotes que pedem "todos os desafios" pedem estes).
    POSSIBLE = LIST.select { |challenge| challenge[:check] }.pluck(:number).freeze
    # Os que a página mostra: todos menos os dois de Match ("vencer uma partida melhor de três"
    # e "vencer a partida inteira com o efeito de uma carta"). Os outros mantêm o número, que é
    # o que fica gravado em user_challenges.
    MATCH_ONLY = [ 25, 38 ].freeze
    SHOWN = LIST.reject { |challenge| MATCH_ONLY.include?(challenge[:number]) }.freeze
    # As cartas que os desafios olham pelo nome.
    CARD_NAMES = [ *XYZ_SERIES, *SACRED_BEASTS, "VWXYZ-Dragon Catapult Cannon", "Huge Revolution" ].freeze

    module_function

    # Os números dos desafios que este duelo conclui.
    def completed(duel)
      LIST.filter_map do |challenge|
        next if challenge[:check].nil? || (challenge[:scope] == :win && !duel.won)

        challenge[:number] if challenge[:check].call(duel)
      end
    end

    def label(number) = LIST.fetch(number - 1)[:label]
  end
end
