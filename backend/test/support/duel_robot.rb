# Um jogador que escolhe ao acaso entre as opções que a engine oferece, para os testes que
# jogam duelos inteiros (GXP-64). Cada escolha é o JSON que a tela mandaria, montado com as
# mesmas regras que a engine confere (playerop.cpp). "seen" conta as perguntas que vieram.
class DuelRobot
  IDLE = { summonable: "summon", spsummonable: "spsummon", repositionable: "reposition", msetable: "mset",
           ssetable: "sset", activatable: "activate" }.freeze
  MZONE = 0x04
  SZONE = 0x08

  attr_reader :seen

  def initialize(random, codes)
    @random = random
    @codes = codes
    @seen = Hash.new(0)
    @actions_this_turn = 0
  end

  def choose(prompt)
    type = prompt[:type].to_sym
    @seen[type] += 1
    public_send(type, prompt)
  end

  # Fase principal: age algumas vezes, depois vai para a batalha ou encerra.
  def select_idlecmd(prompt)
    @actions_this_turn += 1
    actions = IDLE.flat_map { |key, command| prompt[key].each_index.map { |index| { command:, index: } } }
    actions.reject! { |action| action[:command] == "reposition" } if @random.rand < 0.7
    return actions.sample(random: @random) if actions.any? && @actions_this_turn < 12 && @random.rand < 0.75

    @actions_this_turn = 0
    return { command: "battle" } if prompt[:to_bp] && (!prompt[:to_ep] || @random.rand < 0.8)
    return { command: "end" } if prompt[:to_ep]

    actions.sample(random: @random) # nem batalha nem fim de turno: só sobra agir
  end

  def select_battlecmd(prompt)
    if prompt[:attackable].any? && @random.rand < 0.85
      { command: "attack", index: @random.rand(prompt[:attackable].size) }
    elsif prompt[:activatable].any? && @random.rand < 0.3
      { command: "activate", index: @random.rand(prompt[:activatable].size) }
    else
      prompt[:to_m2] && @random.rand < 0.3 ? { command: "main2" } : { command: "end" }
    end
  end

  def select_chain(prompt)
    chains = prompt[:chains]
    return { index: -1 } if chains.empty? || (!prompt[:forced] && @random.rand < 0.5)

    { index: @random.rand(chains.size) }
  end

  def select_effectyn(_prompt) = { yes: @random.rand < 0.7 }
  def select_yesno(_prompt) = { yes: @random.rand < 0.6 }
  def select_option(prompt) = { index: @random.rand(prompt[:options].size) }
  def announce_number(prompt) = { index: @random.rand(prompt[:options].size) }
  def rock_paper_scissors(_prompt) = { hand: @random.rand(1..3) }

  def select_position(prompt)
    { position: [ 0x1, 0x2, 0x4, 0x8 ].select { |bit| prompt[:positions].anybits?(bit) }.sample(random: @random) }
  end

  def select_card(prompt)
    cards = prompt[:cards]
    return { cancel: true } if prompt[:cancelable] && @random.rand < 0.1

    count = @random.rand(prompt[:min].clamp(1, cards.size)..prompt[:max].clamp(1, cards.size))
    { indexes: cards.each_index.to_a.sample(count, random: @random) }
  end

  # Tributo: soma do release_param até o mínimo, sem passar do máximo de cartas.
  def select_tribute(prompt)
    chosen = []
    total = 0
    prompt[:cards].each_index.to_a.shuffle(random: @random).each do |index|
      break if total >= prompt[:min]

      chosen << index
      total += prompt[:cards][index][:release_param]
    end
    return { cancel: true } if total < prompt[:min] || chosen.size > prompt[:max]

    { indexes: chosen }
  end

  # Soma: procura uma combinação que a engine aceita, nas duas regras.
  def select_sum(prompt)
    must = prompt[:must].map { |card| card[:sum] }
    sums = prompt[:cards].map { |card| card[:sum] }
    options = (1..[ sums.size, 12 ].min).flat_map { |size| sums.each_index.to_a.combination(size).to_a }
    valid = options.select { |indexes| sum_valid?(prompt, must + sums.values_at(*indexes), indexes.size) }
    raise "nenhuma soma possível: #{prompt.inspect}" if valid.empty?

    { indexes: valid.sample(random: @random) }
  end

  def sum_valid?(prompt, values, count)
    acc = prompt[:acc]
    return count.between?(prompt[:min], prompt[:max]) && exact_sum?(values, acc) if prompt[:select_max]

    low = values.map { |value| pair(value).then { |normal, other| other.positive? && other < normal ? other : normal } }
    high = values.sum { |value| pair(value).max }
    high >= acc && low.sum - low.min < acc
  end

  def exact_sum?(values, acc, index = 0)
    return false if acc <= 0 || index == values.size

    normal, other = pair(values[index])
    return acc == normal || acc == other if index == values.size - 1

    (acc > normal && exact_sum?(values, acc - normal, index + 1)) || (other.positive? && acc > other && exact_sum?(values, acc - other, index + 1))
  end

  def pair(value) = [ value & 0xFFFF, value >> 16 ]

  # Uma por vez: escolhe mais, às vezes tira, e conclui quando já vale.
  def select_unselect_card(prompt)
    selectable = prompt[:selectable]
    unselectable = prompt[:unselectable]
    return { index: -1 } if prompt[:finishable] && (selectable.empty? || @random.rand < 0.5)
    return { index: @random.rand(selectable.size) } if selectable.any? && (unselectable.empty? || @random.rand < 0.9)
    return { index: selectable.size + @random.rand(unselectable.size) } if unselectable.any?

    { index: -1 }
  end

  # Zona para desativar: as livres do "flag" (bit ligado = não vale), dos dois lados.
  def select_disfield(prompt)
    player = prompt[:player]
    free = [ player, 1 - player ].each_with_index.flat_map do |owner, side|
      [ [ MZONE, 0, 0..4 ], [ SZONE, 8, 0..5 ] ].flat_map do |location, first_bit, sequences|
        sequences.filter_map { |sequence| [ owner, location, sequence ] if prompt[:flag][first_bit + sequence + (16 * side)].zero? }
      end
    end
    { places: free.sample(prompt[:count], random: @random).flatten }
  end
  alias select_place select_disfield

  # Marcadores: reparte a quantidade entre as cartas, sem passar do que cada uma tem.
  def select_counter(prompt)
    counts = Array.new(prompt[:cards].size, 0)
    prompt[:count].times do
      open = prompt[:cards].each_index.select { |index| counts[index] < prompt[:cards][index][:counters] }
      counts[open.sample(random: @random)] += 1
    end
    { counts: }
  end

  def sort_card(prompt)
    return {} if @random.rand < 0.5

    { order: prompt[:cards].each_index.to_a.shuffle(random: @random) }
  end
  alias sort_chain sort_card

  def announce_race(prompt) = { mask: pick_bits(prompt[:available], prompt[:count]) }
  def announce_attrib(prompt) = { mask: pick_bits(prompt[:available], prompt[:count]) }
  def announce_card(_prompt) = { code: @codes.sample(random: @random) }

  def pick_bits(available, count)
    bits = (0..63).select { |bit| available[bit] == 1 }
    bits.sample(count, random: @random).sum { |bit| 1 << bit }
  end
end
