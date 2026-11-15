import { useState } from "react";
import type { DuelEvent, Place } from "./api.ts";

// Animações da mesa (escopo 3.7, "velocidade das animações"): normais, rápidas ou
// desligadas, escolha lembrada no navegador. Com "reduzir movimento" no aparelho, nada se
// mexe de lugar: o PV que muda só aparece e some.
export type Motion = "normal" | "fast" | "off";

export const MOTIONS: [Motion, string][] = [
  ["normal", "Normais"],
  ["fast", "Rápidas"],
  ["off", "Desligadas"],
];

// Quanto dura um movimento (o ataque, a pilha do cemitério), em milissegundos.
export const DURATION: Record<Motion, number> = { normal: 300, fast: 150, off: 0 };

const KEY = "gx-animacoes-do-duelo";

function saved(): Motion {
  try {
    const value = localStorage.getItem(KEY);
    return value === "fast" || value === "off" ? value : "normal";
  } catch {
    return "normal";
  }
}

export function useMotion(): [Motion, (value: Motion) => void] {
  const [motion, setMotion] = useState<Motion>(saved);

  function choose(value: Motion) {
    setMotion(value);
    try {
      localStorage.setItem(KEY, value);
    } catch {
      // Sem armazenamento (aba anônima, por exemplo): vale só nesta visita.
    }
  }

  return [motion, choose];
}

// Os eventos que chegaram depois que a mesa abriu: só eles animam. O que já estava no
// histórico quando a página abriu fica parado.
export function useFreshEvents(events: DuelEvent[] | undefined): DuelEvent[] {
  const [openedAt, setOpenedAt] = useState<number | null>(null);
  if (openedAt === null && events) setOpenedAt(lastId(events));
  if (openedAt === null || !events) return [];
  return events.filter((event) => event.id > openedAt);
}

export function lastId(events: DuelEvent[]) {
  return events.reduce((last, event) => Math.max(last, event.id), 0);
}

// A última mudança de PV de cada time entre os eventos novos: o número que sobe e some.
export function lpChanges(events: DuelEvent[]) {
  const changes = new Map<number, DuelEvent>();
  for (const event of events) if (event.type === "lp") changes.set(Number(event.team), event);
  return changes;
}

// Locais da engine (LOCATION_*), os mesmos do data-place da mesa.
const MONSTERS = 0x04;
const GRAVE = 0x10;

// O ataque (o monstro avança e volta) e a carta que vai para o cemitério (a pilha pulsa).
// São movimentos de um instante, sem estado na tela: o Web Animations API basta.
export function play(root: HTMLElement, events: DuelEvent[], you: number, duration: number) {
  for (const event of events) {
    if (event.type === "attack") {
      const attacker = event.attacker as Place;
      const card = root.querySelector(
        `[data-place="${attacker.controller}-${MONSTERS}-${attacker.sequence}"] .card`,
      );
      const step = attacker.controller === you ? "-0.75rem" : "0.75rem";
      card?.animate([{ translate: "0 0" }, { translate: `0 ${step}` }, { translate: "0 0" }], {
        duration,
        easing: "ease-in-out",
      });
    }
    const to = event.to as Place | undefined;
    if (event.type === "move" && to?.location === GRAVE) {
      root
        .querySelector(`[data-place="${to.controller}-${GRAVE}"]`)
        ?.animate([{ scale: 1 }, { scale: 1.12 }, { scale: 1 }], { duration, easing: "ease-out" });
    }
  }
}
