import { useState } from "react";

// A pergunta da corrente (escopo 3.7): no Automático (GXP-143), a mesa só pergunta quando
// alguma carta tem motivo para responder; com "Sempre" (GXP-84), pergunta em toda janela,
// até sem nada para encadear, e o oponente não fica sabendo pelo passe automático. Fica no
// navegador, como as animações; a mesa manda a escolha para cada duelo.
const KEY = "gx-corrente-do-duelo";

function saved() {
  try {
    return localStorage.getItem(KEY) === "always";
  } catch {
    return false;
  }
}

export function useAlwaysChain(): [boolean, (value: boolean) => void] {
  const [always, setAlways] = useState(saved);

  function choose(value: boolean) {
    setAlways(value);
    try {
      localStorage.setItem(KEY, value ? "always" : "auto");
    } catch {
      // Sem armazenamento (aba anônima, por exemplo): vale só nesta visita.
    }
  }

  return [always, choose];
}
