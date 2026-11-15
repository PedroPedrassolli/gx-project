import { displayName, type CardSummary, type Language } from "../catalog/cards.ts";
import type { DuelEvent, Place } from "./api.ts";

// Uma linha do log da mesa para cada evento do duelo (Duel::Events). Nil quando o evento não
// vale uma linha (as fases que a trilha da mesa já mostra, a corrente que terminou, a carta
// que entra no campo pela invocação, que já tem linha própria).

type Context = {
  you: number;
  names: string[];
  cards: Map<number, CardSummary>;
  language: Language;
};

// Locais (LOCATION_*), posições (POS_*) e motivos (REASON_*) da engine.
const DECK = 0x01;
const HAND = 0x02;
const MONSTERS = 0x04;
const SPELLS = 0x08;
const GRAVE = 0x10;
const BANISHED = 0x20;
const EXTRA = 0x40;
const FACE_UP = 0x1 | 0x4;
const DEFENSE = 0x4 | 0x8;
const DESTROY = 0x1;
const RELEASE = 0x2;
const BATTLE = 0x20;
const DISCARD = 0x4000;

const BATTLE_PHASE = 0x08;
const HANDS: Record<number, string> = { 1: "tesoura", 2: "pedra", 3: "papel" };

function who(team: number, ctx: Context, start = true) {
  if (team === ctx.you) return start ? "Você" : "você";
  return ctx.names[team] ?? "Duelista";
}

// Nome da carta, ou nil quando este lado não sabe qual é (código 0).
function cardName(code: unknown, ctx: Context) {
  if (typeof code !== "number" || code === 0) return null;
  const card = ctx.cards.get(code);
  return card ? displayName(card, ctx.language) : `Carta ${code}`;
}

// "Mago Negro" ou "Mago Negro e Renascer do Monstro".
function names(codes: number[], ctx: Context) {
  const list = codes.map((code) => cardName(code, ctx) ?? "uma carta");
  return list.length > 1 ? `${list.slice(0, -1).join(", ")} e ${list.at(-1)}` : (list[0] ?? "");
}

function move(event: DuelEvent, ctx: Context) {
  const from = event.from as Place;
  const to = event.to as Place;
  const reason = Number(event.reason);
  const name = cardName(event.code, ctx);
  const subject = name ? `A carta ${name}` : "Uma carta";
  switch (to.location) {
    case GRAVE:
      if (reason & DESTROY)
        return `${subject} foi destruída${reason & BATTLE ? " em batalha" : ""}.`;
      if (reason & RELEASE) return `${subject} foi oferecida como Tributo.`;
      if (reason & DISCARD) return `${subject} foi descartada.`;
      return `${subject} foi para o Cemitério.`;
    case BANISHED:
      return `${subject} foi banida.`;
    case HAND:
      if (from.location === DECK)
        return `${who(to.controller, ctx)} adicionou ${name ?? "uma carta"} do Deck à mão.`;
      return `${subject} voltou para a mão.`;
    case DECK:
      return `${subject} voltou para o Deck.`;
    case EXTRA:
      return `${subject} voltou para o Extra.`;
    default: {
      // No campo, só a troca de lado vale linha: a entrada já tem a da invocação ou ativação.
      const field = [MONSTERS, SPELLS];
      if (
        field.includes(from.location) &&
        field.includes(to.location) &&
        from.controller !== to.controller
      )
        return `${who(to.controller, ctx)} assumiu o controle de ${name ?? "uma carta"}.`;
      return null;
    }
  }
}

function position(event: DuelEvent, ctx: Context) {
  const before = Number(event.from);
  const after = Number(event.to);
  const name = cardName(event.code, ctx);
  const subject = name ? `A carta ${name}` : "Uma carta";
  if (!(before & FACE_UP) && after & FACE_UP) return `${subject} foi virada para cima.`;
  if (before & FACE_UP && !(after & FACE_UP)) return `${subject} foi virada para baixo.`;
  return `${subject} mudou para Posição de ${after & DEFENSE ? "Defesa" : "Ataque"}.`;
}

function attack(event: DuelEvent, ctx: Context) {
  const attacker = event.attacker as Place;
  const target = event.target as Place | null;
  const subject = cardName(attacker.code, ctx) ?? "Um monstro";
  if (!target) return `${subject} atacou diretamente.`;
  return `${subject} atacou ${cardName(target.code, ctx) ?? "um monstro com a face para baixo"}.`;
}

export function describe(event: DuelEvent, ctx: Context): string | null {
  const team = Number(event.team);
  switch (event.type) {
    case "turn":
      return team === ctx.you
        ? "Novo turno: é a sua vez."
        : `Novo turno: vez de ${who(team, ctx)}.`;
    case "phase":
      // As outras fases a trilha do meio da mesa já mostra; a Batalha vale a linha.
      return Number(event.phase) === BATTLE_PHASE ? "Fase de Batalha." : null;
    case "draw": {
      const codes = event.codes as number[] | undefined;
      const count = codes?.length ?? Number(event.count);
      if (count === 0) return null;
      if (codes) return `${who(team, ctx)} comprou ${names(codes, ctx)}.`;
      return `${who(team, ctx)} comprou ${count === 1 ? "1 carta" : `${count} cartas`}.`;
    }
    case "summon": {
      const subject = who(Number(event.controller), ctx);
      const name = cardName(event.code, ctx);
      if (event.kind === "flip")
        return `${subject} virou ${name ?? "uma carta"} para cima (Invocação-Virar).`;
      const card = name ?? "uma carta com a face para baixo";
      return `${subject} invocou ${card}${event.kind === "special" ? " por Invocação-Especial" : ""}.`;
    }
    case "set": {
      const hidden = Number(event.location) === MONSTERS ? "um monstro" : "uma magia ou armadilha";
      return `${who(Number(event.controller), ctx)} baixou ${cardName(event.code, ctx) ?? hidden}.`;
    }
    case "move":
      return move(event, ctx);
    case "position":
      return position(event, ctx);
    case "chain":
      return `Elo ${Number(event.link)}: ${who(Number(event.controller), ctx, false)} ativou ${cardName(event.code, ctx) ?? "uma carta"}.`;
    case "chain_negated":
      return `O elo ${Number(event.link)} foi negado.`;
    case "attack":
      return attack(event, ctx);
    case "lp": {
      const amount = Number(event.amount).toLocaleString("pt-BR");
      const verb =
        { damage: "perdeu", recover: "ganhou", cost: "pagou" }[String(event.kind)] ?? "mudou";
      return `${who(team, ctx)} ${verb} ${amount} PV.`;
    }
    case "reveal": {
      const revealed = (event.cards as { code: number }[]).map((card) => card.code);
      return `${revealed.length > 1 ? "Reveladas" : "Revelada"}: ${names(revealed, ctx)}.`;
    }
    case "coin":
      return `Moeda: ${(event.results as number[]).map((side) => (side ? "cara" : "coroa")).join(", ")}.`;
    case "dice":
      return `Dado: ${(event.results as number[]).join(", ")}.`;
    case "hands": {
      const [first, second] = event.hands as number[];
      return `Pedra, papel e tesoura: ${who(0, ctx, false)}, ${HANDS[first ?? 0]}; ${who(1, ctx, false)}, ${HANDS[second ?? 0]}.`;
    }
    case "win": {
      const player = Number(event.player);
      return player === 2 ? "Empate." : `${who(player, ctx)} venceu.`;
    }
    default:
      return null;
  }
}
