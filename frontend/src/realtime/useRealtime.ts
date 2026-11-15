import { useEffect, useRef, useState } from "react";
import { BaseRealtime, FetchRequest, WebSocketTransport } from "ably/modular";
import type { TokenRequest } from "ably";
import { request } from "../api.ts";

// Tempo real (ADR 0002): só nas telas de sala e de duelo. O navegador assina o canal do
// próprio jogador no Ably, com o pedido de token que o Rails assina. Se o tempo real não
// vier (sem a chave, Ably fora do ar ou no limite do plano), a tela consulta a API a cada
// POLL_MS: o modo devolvido diz qual dos dois está valendo.
export type RealtimeMode = "connecting" | "live" | "polling";

export const POLL_MS = 2000;
// Aba escondida por esse tempo fecha a conexão: o plano grátis tem 200 conexões ao mesmo tempo.
const HIDDEN_CLOSE_MS = 2 * 60 * 1000;

const tokenRequest = async () =>
  (await request<{ data: TokenRequest }>("POST", "/api/realtime/token")).data;

export function useRealtime(
  userId: number | undefined,
  onEvent: (name: string, data: unknown) => void,
): RealtimeMode {
  const [mode, setMode] = useState<RealtimeMode>("connecting");
  // A função mais nova da tela, sem refazer a conexão a cada render.
  const handler = useRef(onEvent);
  useEffect(() => {
    handler.current = onEvent;
  });

  useEffect(() => {
    if (userId === undefined) return;
    let client: BaseRealtime | undefined;
    let hiddenTimer: number | undefined;
    let stopped = false;

    // O primeiro pedido de token decide: sem ele, nem cria a conexão.
    tokenRequest().then(
      (first) => {
        if (stopped) return;
        let pending: TokenRequest | undefined = first;
        client = new BaseRealtime({
          // O primeiro token já veio; os próximos renovam (cada um vale 1 hora).
          authCallback: (_params, callback) => {
            const next = pending ? Promise.resolve(pending) : tokenRequest();
            pending = undefined;
            next.then(
              (value) => callback(null, value),
              (error: unknown) => callback(String(error), null),
            );
          },
          plugins: { WebSocketTransport, FetchRequest },
        });
        client.connection.on((change) => {
          if (change.current === "connected") setMode("live");
          else if (change.current !== "connecting") setMode("polling");
        });
        client.channels
          .get(`private:user:${userId}`)
          .subscribe((message) => handler.current(message.name ?? "", message.data));
      },
      () => {
        if (!stopped) setMode("polling");
      },
    );

    function onVisibility() {
      if (document.hidden) {
        hiddenTimer = window.setTimeout(() => client?.connection.close(), HIDDEN_CLOSE_MS);
      } else {
        window.clearTimeout(hiddenTimer);
        if (client?.connection.state === "closed") client.connection.connect();
      }
    }
    document.addEventListener("visibilitychange", onVisibility);

    return () => {
      stopped = true;
      window.clearTimeout(hiddenTimer);
      document.removeEventListener("visibilitychange", onVisibility);
      client?.close();
    };
  }, [userId]);

  return mode;
}
