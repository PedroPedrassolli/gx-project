import { Link } from "react-router";
import type { RoomSummary } from "./api.ts";
import { decisionChip, duelChip } from "./times.ts";

// Uma sala aberta (GXP-134): a inicial de quem criou, o nome da sala, quantos já entraram e
// as regras em fichas. O link é o nome, e o cartão inteiro responde ao toque.
export function RoomCard({ room }: { room: RoomSummary }) {
  return (
    <li className="room-card">
      <span className="avatar-initial" aria-hidden="true">
        {room.owner.slice(0, 1).toUpperCase()}
      </span>
      <h3>
        <Link to={`/salas/${room.code}`}>Sala de {room.owner}</Link>
      </h3>
      <span className="room-seats">
        {room.players} de {room.seats}
      </span>
      <ul className="room-chips" aria-label="Regras">
        <li>{room.banlist ? "Banlist do jogo" : "Sem banlist"}</li>
        <li>{room.destiny_draw ? "Com Destiny Draw" : "Sem Destiny Draw"}</li>
        <li>{decisionChip(room.decision_seconds)}</li>
        <li>{duelChip(room.duel_minutes)}</li>
      </ul>
    </li>
  );
}
