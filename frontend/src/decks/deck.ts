import { displayName, type CardSummary, type Language } from "../catalog/cards.ts";

// O deck na tela do Deck Edit: as linhas como a API manda (ADR 0009), as edições e a
// validação ao vivo, com as mesmas regras e mensagens do Decks::Validator do backend
// (escopo 3.3). A validação que vale é a do backend, ao salvar.

export type Section = "main" | "extra" | "side";
export type DeckRow = { card_id: number; section: Section; quantity: number; destiny: boolean };

export const SECTIONS: Record<Section, { title: string; min: number; max: number }> = {
  main: { title: "Main Deck", min: 40, max: 60 },
  extra: { title: "Extra Deck", min: 0, max: 15 },
  side: { title: "Side Deck", min: 0, max: 15 },
};
export const MAX_COPIES = 3;
const BANLIST_COPIES = { forbidden: 0, limited: 1, semi_limited: 2 };
const EXTRA_DECK_TYPES = ["Fusion", "Synchro"];

export function goesToExtra(card: CardSummary) {
  return (card.monster_types ?? []).some((type) => EXTRA_DECK_TYPES.includes(type));
}

export function sectionCount(rows: DeckRow[], section: Section) {
  return rows.filter((row) => row.section === section).reduce((sum, row) => sum + row.quantity, 0);
}

export function copies(rows: DeckRow[], cardId: number) {
  return rows.filter((row) => row.card_id === cardId).reduce((sum, row) => sum + row.quantity, 0);
}

export type DeckEdit =
  | { type: "add"; cardId: number; section: Section }
  | { type: "remove"; cardId: number; section: Section }
  | { type: "destiny"; cardId: number }
  | { type: "move"; cardId: number; from: Section; to: Section };

// Aplica uma edição e devolve as linhas novas. Adicionar para em 3 cópias no deck todo.
export function editDeck(rows: DeckRow[], edit: DeckEdit): DeckRow[] {
  switch (edit.type) {
    case "add":
      if (copies(rows, edit.cardId) >= MAX_COPIES) return rows;
      return change(rows, edit.cardId, edit.section, +1);
    case "remove":
      return change(rows, edit.cardId, edit.section, -1);
    case "destiny":
      return rows.map((row) =>
        row.card_id === edit.cardId && row.section === "main"
          ? { ...row, destiny: !row.destiny }
          : row,
      );
    case "move":
      return change(change(rows, edit.cardId, edit.from, -1), edit.cardId, edit.to, +1);
  }
}

function change(rows: DeckRow[], cardId: number, section: Section, amount: number): DeckRow[] {
  const found = rows.some((row) => row.card_id === cardId && row.section === section);
  const changed = found
    ? rows.map((row) =>
        row.card_id === cardId && row.section === section
          ? { ...row, quantity: row.quantity + amount }
          : row,
      )
    : [...rows, { card_id: cardId, section, quantity: amount, destiny: false }];
  return changed.filter((row) => row.quantity > 0);
}

// Os erros, na ordem do backend: tamanho das seções e, depois, cada carta pelo nome.
export function deckErrors(
  rows: DeckRow[],
  cards: Map<number, CardSummary>,
  owned: Map<number, number>,
  language: Language,
): string[] {
  const sizes = (Object.keys(SECTIONS) as Section[]).flatMap((section) => {
    const { title, min, max } = SECTIONS[section];
    const count = sectionCount(rows, section);
    if (count >= min && count <= max) return [];
    return min === 0
      ? [`O ${title} pode ter até ${max} cartas (tem ${count}).`]
      : [`O ${title} precisa ter de ${min} a ${max} cartas (tem ${count}).`];
  });

  const ids = [...new Set(rows.map((row) => row.card_id))].filter((id) => cards.has(id));
  const named = ids
    .map((id) => ({ id, card: cards.get(id) as CardSummary }))
    .map((item) => ({ ...item, name: displayName(item.card, language) }))
    .sort((a, b) => a.name.localeCompare(b.name, "pt-BR"));

  return [
    ...sizes,
    ...named.flatMap(({ id, card, name }) =>
      cardErrors(
        rows.filter((row) => row.card_id === id),
        card,
        name,
        owned.get(id) ?? 0,
      ),
    ),
  ];
}

function cardErrors(rows: DeckRow[], card: CardSummary, name: string, owned: number): string[] {
  const count = rows.reduce((sum, row) => sum + row.quantity, 0);
  const errors: string[] = [];
  if (count > MAX_COPIES)
    errors.push(
      `${name}: no máximo ${MAX_COPIES} cópias somando Main, Extra e Side (tem ${count}).`,
    );
  if (card.banlist === "forbidden") errors.push(`${name} está proibida.`);
  if (card.banlist === "limited" && count > BANLIST_COPIES.limited)
    errors.push(`${name} é limitada: no máximo 1 cópia (tem ${count}).`);
  if (card.banlist === "semi_limited" && count > BANLIST_COPIES.semi_limited)
    errors.push(`${name} é semi-limitada: no máximo 2 cópias (tem ${count}).`);
  if (count > owned) errors.push(`${name}: você tem ${owned} e o deck usa ${count}.`);
  for (const row of rows) {
    if (goesToExtra(card) && row.section === "main")
      errors.push(`${name} é de Fusão ou Sincro: vai no Extra Deck.`);
    if (!goesToExtra(card) && row.section === "extra")
      errors.push(`${name} não é de Fusão nem Sincro: não vai no Extra Deck.`);
  }
  for (const row of rows) {
    if (row.destiny && row.section !== "main")
      errors.push(`${name} só pode ser Destiny no Main Deck.`);
  }
  return errors;
}
