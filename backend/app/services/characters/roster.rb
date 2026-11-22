module Characters
  # Os personagens para duelar contra o computador (escopo 3.10; ADR 0013), na ordem em que
  # são liberados. Os dados ficam em db/seeds/jogo/personagens.yml, escrito à mão a partir das
  # listas de deck da Yugipedia; aqui viram objetos simples, lidos do arquivo uma vez só.
  module Roster
    FILE = Rails.root.join("db/seeds/jogo/personagens.yml")
    # O bônus de DP da vitória cresce com a ordem: o primeiro paga 60, o último (o Yugi), 840.
    BONUS_PER_POSITION = 60

    # skill: o jeito de o computador jogar, de 1 (erra de propósito às vezes) a 3.
    Group = Data.define(:id, :name, :skill)
    # main e extra: { nome da carta => cópias }. swaps: as cartas que saíram da lista da fonte
    # (fora do pool) e as que entraram no lugar.
    Deck = Data.define(:name, :level, :source, :swaps, :main, :extra) do
      def card_names = (main.keys + extra.keys).uniq
    end
    # position: 1 para o primeiro da lista.
    Character = Data.define(:id, :position, :name, :group, :description, :signature, :deck) do
      def skill = group.skill
      def victory_bonus = BONUS_PER_POSITION * position
    end

    module_function

    def all = @all ||= load

    def find(id) = all.find { |character| character.id == id }

    # Quem vem depois na ordem (nil depois do último).
    def after(character) = all[character.position]

    # Quem vem antes na ordem (nil antes do primeiro).
    def before(character) = (all[character.position - 2] if character.position > 1)

    def load
      data = YAML.safe_load_file(FILE)
      groups = data["grupos"].to_h { |group| [ group["id"], Group.new(id: group["id"], name: group["nome"], skill: group["computador"]) ] }
      data["personagens"].each_with_index.map do |character, index|
        Character.new(id: character["id"], position: index + 1, name: character["nome"], group: groups.fetch(character["grupo"]),
                      description: character["descricao"], signature: character["carta_simbolo"], deck: deck(character["deck"]))
      end.freeze
    end

    def deck(data)
      cards = ->(rows) { rows.to_a.to_h { |row| [ row["nome"], row["quantidade"] ] } }
      Deck.new(name: data["nome"], level: data["nivel"], source: data["fonte"], swaps: data["trocas"].to_a,
               main: cards.call(data["principal"]), extra: cards.call(data["extra"]))
    end
  end
end
