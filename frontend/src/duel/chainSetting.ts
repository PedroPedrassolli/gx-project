import { useState } from "react";

// "Sempre perguntar" na corrente (escopo 3.7; GXP-84): a mesa pergunta mesmo quando você não
// tem o que encadear, e o oponente não fica sabendo pelo passe automático. Fica no navegador,
// como as animações; a mesa manda a escolha para cada duelo.
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
