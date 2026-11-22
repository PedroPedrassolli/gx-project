// Cópia do catálogo e dos textos guardada no navegador (Cache Storage, GXP-122). Com ela, a
// lista e os textos aparecem na hora na volta ao site, mesmo com o servidor acordando (uns
// 4 s depois de 5 min parado) ou logo depois de um deploy, quando a CDN começa vazia. A
// resposta nova chega em segundo plano e substitui a cópia.
const STORE = "gx-dados-v1";

export async function readStored<T>(key: string): Promise<T | undefined> {
  try {
    const response = await (await caches.open(STORE)).match(key);
    return response ? ((await response.json()) as T) : undefined;
  } catch {
    return undefined; // sem Cache Storage (navegador antigo, aba anônima): segue sem cópia
  }
}

// Cheio ou indisponível: tudo bem, na próxima visita busca de novo.
export function writeStored(key: string, value: unknown) {
  try {
    caches
      .open(STORE)
      .then((cache) => cache.put(key, new Response(JSON.stringify(value))))
      .catch(() => undefined);
  } catch {
    // sem Cache Storage
  }
}
