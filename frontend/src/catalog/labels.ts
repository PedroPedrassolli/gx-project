// Rótulos em português dos valores que a API manda em inglês, com os termos das cartas
// impressas em português.
export const CARD_TYPES: Record<string, string> = {
  Monster: "Monstro",
  Spell: "Magia",
  Trap: "Armadilha",
};

// Como aparece depois de "Magia" ou "Armadilha": "Magia de Campo", "Armadilha Contínua".
export const PROPERTIES: Record<string, string> = {
  Normal: "Normal",
  Continuous: "Contínua",
  Equip: "de Equipamento",
  Field: "de Campo",
  "Quick-Play": "Rápida",
  Ritual: "de Ritual",
  Counter: "de Resposta",
};

export const ATTRIBUTES: Record<string, string> = {
  DARK: "TREVAS",
  LIGHT: "LUZ",
  EARTH: "TERRA",
  WATER: "ÁGUA",
  FIRE: "FOGO",
  WIND: "VENTO",
  DIVINE: "DIVINO",
};

export const RACES: Record<string, string> = {
  Aqua: "Aqua",
  Beast: "Besta",
  "Beast-Warrior": "Besta-Guerreira",
  Dinosaur: "Dinossauro",
  "Divine-Beast": "Besta Divina",
  Dragon: "Dragão",
  Fairy: "Fada",
  Fiend: "Demônio",
  Fish: "Peixe",
  Insect: "Inseto",
  Machine: "Máquina",
  Plant: "Planta",
  Psychic: "Psíquico",
  Pyro: "Piro",
  Reptile: "Réptil",
  Rock: "Rocha",
  "Sea Serpent": "Serpente Marinha",
  Spellcaster: "Mago",
  Thunder: "Trovão",
  Warrior: "Guerreiro",
  "Winged Beast": "Besta Alada",
  Zombie: "Zumbi",
};

export const MONSTER_TYPES: Record<string, string> = {
  Normal: "Normal",
  Effect: "Efeito",
  Fusion: "Fusão",
  Ritual: "Ritual",
  Synchro: "Sincro",
  Tuner: "Regulador",
  Flip: "Virar",
  Gemini: "Gêmeos",
  Spirit: "Espírito",
  Toon: "Toon",
  Union: "União",
};

export const RARITIES: Record<string, string> = {
  common: "Comum",
  rare: "Rara",
  super_rare: "Super Rara",
  ultra_rare: "Ultra Rara",
};

export const BANLIST: Record<string, string> = {
  forbidden: "Proibida",
  limited: "Limitada",
  semi_limited: "Semilimitada",
};

// Rótulo de um valor; o que não está na tabela aparece como veio.
export function label(table: Record<string, string>, value: string | undefined): string {
  return value === undefined ? "" : (table[value] ?? value);
}
