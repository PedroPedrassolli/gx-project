module Duel
  # O resumo de uma carta que o catálogo não tem, no mesmo formato do catálogo
  # (Catalog::Snapshot), lido do banco da engine (GXP-141). São as fichas (o Scapegoat cria
  # quatro "Sheep Token") e as cartas que um efeito cria ou renomeia. É o que a mesa mostra
  # delas: nome, tipo, números e texto, em inglês, como vêm do BabelCDB.
  module CardSummary
    CARD_TYPES = { 0x1 => "Monster", 0x2 => "Spell", 0x4 => "Trap" }.freeze
    TOKEN = 0x4000
    # Na ordem em que o catálogo escreve os tipos ("Synchro", "Tuner", "Effect").
    MONSTER_TYPES = { 0x40 => "Fusion", 0x80 => "Ritual", 0x2000 => "Synchro", 0x200 => "Spirit", 0x400 => "Union",
                      0x800 => "Gemini", 0x400000 => "Toon", 0x1000 => "Tuner", 0x200000 => "Flip",
                      0x10 => "Normal", 0x20 => "Effect" }.freeze
    PROPERTIES = { 0x10000 => "Quick-Play", 0x20000 => "Continuous", 0x40000 => "Equip", 0x80000 => "Field",
                   0x100000 => "Counter", 0x80 => "Ritual" }.freeze
    ATTRIBUTES = { 0x1 => "EARTH", 0x2 => "WATER", 0x4 => "FIRE", 0x8 => "WIND", 0x10 => "LIGHT", 0x20 => "DARK",
                   0x40 => "DIVINE" }.freeze
    RACES = { 0x1 => "Warrior", 0x2 => "Spellcaster", 0x4 => "Fairy", 0x8 => "Fiend", 0x10 => "Zombie", 0x20 => "Machine",
              0x40 => "Aqua", 0x80 => "Pyro", 0x100 => "Rock", 0x200 => "Winged Beast", 0x400 => "Plant", 0x800 => "Insect",
              0x1000 => "Thunder", 0x2000 => "Dragon", 0x4000 => "Beast", 0x8000 => "Beast-Warrior", 0x10000 => "Dinosaur",
              0x20000 => "Fish", 0x40000 => "Sea Serpent", 0x80000 => "Reptile", 0x100000 => "Psychic",
              0x200000 => "Divine-Beast" }.freeze
    # Os códigos oficiais têm até 8 dígitos. Os do anime (100..., 511...) não têm imagem.
    LAST_OFFICIAL = 99_999_999
    UNKNOWN = -2 # o "?" no ATK ou na DEF

    module_function

    # nil quando a engine não conhece o código.
    def call(code, database = Engine.cards)
      card = database.find(code)
      name, text = database.texts(code)
      return unless card && name

      card_type = CARD_TYPES.find { |bit, _| card.type.anybits?(bit) }&.last
      details = card_type == "Monster" ? monster(card) : { property: property(card.type) }
      { code:, name:, card_type:, **details, text:, image: (code if code <= LAST_OFFICIAL) }.compact
    end

    # A ficha fica só com "Token": no .cdb ela também é Normal, mas a carta mostra "Ficha".
    def monster(card)
      types = card.type.anybits?(TOKEN) ? [ "Token" ] : MONSTER_TYPES.filter_map { |bit, type| type if card.type.anybits?(bit) }
      { attribute: ATTRIBUTES[card.attribute], race: RACES[card.race], monster_types: types, level: card.level,
        atk: stat(card.attack), def: stat(card.defense) }
    end

    def property(type) = PROPERTIES.find { |bit, _| type.anybits?(bit) }&.last || "Normal"

    def stat(value) = (value unless value == UNKNOWN)
  end
end
