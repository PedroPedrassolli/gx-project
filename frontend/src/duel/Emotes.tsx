import { useEffect, useState } from "react";
import { PlainDialog } from "./DuelDialogs.tsx";
import { EMOTES, EMOTE_MS, visibleEmotes, type EmotePlayer } from "./emotes.ts";

// As frases que aparecem agora. O relógio só anda quando uma frase precisa sumir.
export function useEmoteBubbles(players: EmotePlayer[]) {
  const [now, setNow] = useState(() => Date.now());
  const latest = Math.max(0, ...players.map((player) => Date.parse(player.emote_at ?? "") || 0));
  useEffect(() => {
    const wait = latest + EMOTE_MS - Date.now();
    if (wait <= 0) return;
    const timer = setTimeout(() => setNow(Date.now()), wait + 50);
    return () => clearTimeout(timer);
  }, [latest]);
  return visibleEmotes(players, Math.max(now, latest));
}

// As frases fixas: o botão "Frases" da barra abre um modal, que fecha depois de mandar.
export function EmotePicker(props: {
  pending: boolean;
  error?: string;
  onSend: (emote: string) => void;
}) {
  const [open, setOpen] = useState(false);
  return (
    <>
      <button type="button" className="secondary" onClick={() => setOpen(true)}>
        Frases
      </button>
      <PlainDialog id="emotes-title" title="Frases" open={open} onClose={() => setOpen(false)}>
        <div className="emote-list">
          {EMOTES.map((item) => (
            <button
              key={item.key}
              type="button"
              disabled={props.pending}
              onClick={() => {
                props.onSend(item.key);
                setOpen(false);
              }}
            >
              {item.text}
            </button>
          ))}
        </div>
      </PlainDialog>
      {props.error && (
        <p role="alert" className="form-error duel-bar-error">
          {props.error}
        </p>
      )}
    </>
  );
}
