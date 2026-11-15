import { useEffect, useRef, useState } from "react";
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

// As frases fixas, num menu que fecha depois de mandar.
export function EmotePicker(props: {
  pending: boolean;
  error?: string;
  onSend: (emote: string) => void;
}) {
  const details = useRef<HTMLDetailsElement>(null);
  return (
    <details className="emotes" ref={details}>
      <summary>Mensagens</summary>
      <div className="emote-list">
        {EMOTES.map((item) => (
          <button
            key={item.key}
            type="button"
            disabled={props.pending}
            onClick={() => {
              props.onSend(item.key);
              details.current?.removeAttribute("open");
            }}
          >
            {item.text}
          </button>
        ))}
      </div>
      {props.error && (
        <p role="alert" className="form-error">
          {props.error}
        </p>
      )}
    </details>
  );
}
