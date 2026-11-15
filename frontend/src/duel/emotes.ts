// As frases da mesa (escopo 3.7: sem chat livre, só emotes; GXP-83). As chaves são as do
// backend (MatchPlayer::EMOTES).
export const EMOTES = [
  { key: "hello", text: "Olá!" },
  { key: "luck", text: "Boa sorte!" },
  { key: "nice", text: "Boa jogada!" },
  { key: "think", text: "Deixa eu pensar…" },
  { key: "oops", text: "Ops!" },
  { key: "gg", text: "Bom duelo!" },
];

// Por quanto tempo a frase fica no nome de quem mandou.
export const EMOTE_MS = 6000;

export type EmotePlayer = { team: number; emote?: string; emote_at?: string };

// A frase que chegou (do tempo real ou da resposta de quem mandou) entra no jogador dela.
export function withEmote<T extends { players: EmotePlayer[] }>(
  state: T,
  emote: Required<EmotePlayer>,
): T {
  const players = state.players.map((player) =>
    player.team === emote.team
      ? { ...player, emote: emote.emote, emote_at: emote.emote_at }
      : player,
  );
  return { ...state, players };
}

// As frases que ainda aparecem agora, por time.
export function visibleEmotes(players: EmotePlayer[], now: number) {
  const shown = new Map<number, string>();
  for (const player of players) {
    const text = EMOTES.find((item) => item.key === player.emote)?.text;
    if (text && player.emote_at && now - Date.parse(player.emote_at) < EMOTE_MS) {
      shown.set(player.team, text);
    }
  }
  return shown;
}
