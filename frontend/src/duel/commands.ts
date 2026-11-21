import type { Prompt } from "./api.ts";

// As ações da fase principal e da batalha (select_idlecmd e select_battlecmd), agrupadas por
// carta (GXP-99): a carta que dá para usar brilha na mesa, e tocar nela abre as ações dela.
// A chave da carta é "time-local-posição", a mesma das zonas da mesa (actionable.ts).

export type CommandCard = {
  code: number;
  controller: number;
  location: number;
  sequence: number;
  text?: string | null;
};

export type Command = {
  verb: string; // o botão no modal da carta: "Invocar"
  prefix: string; // a frase na lista de todas as ações: "Invocar Mago Negro (mão)"
  command: string;
  index: number; // a posição na lista da pergunta, que vai na resposta
  card: CommandCard;
};

// [lista da pergunta, comando, verbo do modal, começo da frase na lista inteira]
type Group = [string, string, string, string];

const IDLE: Group[] = [
  ["summonable", "summon", "Invocar", "Invocar"],
  ["spsummonable", "spsummon", "Invocar por Invocação-Especial", "Invocar por Invocação-Especial"],
  ["repositionable", "reposition", "Mudar a posição", "Mudar a posição de"],
  ["msetable", "mset", "Baixar", "Baixar"],
  ["ssetable", "sset", "Baixar", "Baixar"],
  ["activatable", "activate", "Ativar", "Ativar"],
];

const BATTLE: Group[] = [
  ["attackable", "attack", "Atacar", "Atacar com"],
  ["activatable", "activate", "Ativar", "Ativar"],
];

export const isCommandPrompt = (prompt?: Prompt) =>
  prompt?.type === "select_idlecmd" || prompt?.type === "select_battlecmd";

export const placeKey = (card: Pick<CommandCard, "controller" | "location" | "sequence">) =>
  `${card.controller}-${card.location}-${card.sequence}`;

// Todas as ações sobre cartas, na ordem da pergunta (invocar, baixar, ativar...).
export function commands(prompt?: Prompt): Command[] {
  if (!isCommandPrompt(prompt)) return [];
  const groups = prompt?.type === "select_idlecmd" ? IDLE : BATTLE;
  return groups.flatMap(([key, command, verb, prefix]) => {
    const cards = (prompt?.[key] as CommandCard[] | undefined) ?? [];
    return cards.map((card, index) => ({ verb, prefix, command, index, card }));
  });
}

// As ações de cada carta, pela chave da carta.
export function commandsByPlace(prompt?: Prompt): Map<string, Command[]> {
  const byPlace = new Map<string, Command[]>();
  for (const item of commands(prompt)) {
    const key = placeKey(item.card);
    byPlace.set(key, [...(byPlace.get(key) ?? []), item]);
  }
  return byPlace;
}

// Mudar de fase e encerrar o turno: os botões da faixa das fases.
export function phaseCommands(prompt?: Prompt): { label: string; command: string }[] {
  if (prompt?.type === "select_idlecmd") {
    return [
      prompt.to_bp ? { label: "Ir para a Batalha", command: "battle" } : null,
      prompt.to_ep ? { label: "Encerrar o turno", command: "end" } : null,
    ].filter((item) => item !== null);
  }
  if (prompt?.type === "select_battlecmd") {
    return [
      prompt.to_m2 ? { label: "Ir para a Principal 2", command: "main2" } : null,
      prompt.to_ep ? { label: "Encerrar o turno", command: "end" } : null,
    ].filter((item) => item !== null);
  }
  return [];
}
