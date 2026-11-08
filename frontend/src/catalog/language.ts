import { useState } from "react";
import type { Language } from "./cards.ts";

// Língua do texto das cartas, lembrada no navegador entre as visitas.
const KEY = "gx-idioma-das-cartas";

function saved(): Language {
  try {
    return localStorage.getItem(KEY) === "en" ? "en" : "pt";
  } catch {
    return "pt";
  }
}

export function useCardLanguage(): [Language, (value: Language) => void] {
  const [language, setLanguage] = useState<Language>(saved);

  function choose(value: Language) {
    setLanguage(value);
    try {
      localStorage.setItem(KEY, value);
    } catch {
      // Sem armazenamento (aba anônima, por exemplo): vale só nesta visita.
    }
  }

  return [language, choose];
}
