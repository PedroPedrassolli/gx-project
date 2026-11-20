import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { useSession } from "../account/session.ts";
import { request } from "../api.ts";
import { SignInFirst } from "../PageNotice.tsx";
import { usePageTitle } from "../pageTitle.ts";

type Challenge = { number: number; label: string; done: boolean; possible: boolean };
type Challenges = { done: number; total: number; challenges: Challenge[] };
type Mission = {
  id: string;
  name: string;
  goal: string;
  reward: string;
  progress: number;
  target: number;
  done: boolean;
  repeats: boolean;
};

// As missões e os desafios (escopo 3.5; GXP-88 e GXP-89). As missões contam vitórias e
// liberam pacotes ou dão cartas; os desafios são os 104 do jogo, na ordem, cada um conta uma
// vez e cada desafio concluído paga 2 DP em todo duelo.
export function ChallengesPage() {
  usePageTitle("Missões e desafios");
  const session = useSession();
  const user = session.data?.user;
  const [onlyMissing, setOnlyMissing] = useState(false);
  const challenges = useQuery({
    queryKey: ["challenges"],
    queryFn: async () => (await request<{ data: Challenges }>("GET", "/api/challenges")).data,
    enabled: Boolean(user),
  });

  const missions = useQuery({
    queryKey: ["missions"],
    queryFn: async () => (await request<{ data: Mission[] }>("GET", "/api/missions")).data,
    enabled: Boolean(user),
  });

  if (session.isSuccess && !user) {
    return (
      <SignInFirst
        title="Missões e desafios"
        reason="para ver as suas missões e os seus desafios"
      />
    );
  }
  const data = challenges.data;
  const list = data?.challenges.filter((challenge) => !onlyMissing || !challenge.done) ?? [];

  return (
    <main className="page narrow">
      <h1>Missões e desafios</h1>
      {missions.data && (
        <section aria-labelledby="missions-title">
          <h2 id="missions-title">Missões</h2>
          <ul className="missions">
            {missions.data.map((mission) => (
              <li key={mission.id} className={mission.done ? "done" : undefined}>
                <h3>{mission.name}</h3>
                <p>
                  {mission.goal}. {mission.reward}.
                </p>
                <p className="mission-progress">
                  <progress value={mission.progress} max={mission.target} aria-hidden="true" />
                  <span>
                    {mission.done
                      ? mission.repeats
                        ? "Concluída nesta semana"
                        : "Concluída"
                      : `${mission.progress} de ${mission.target}`}
                  </span>
                </p>
              </li>
            ))}
          </ul>
          <p className="hint">
            Conta a vitória de um duelo com pelo menos 3 turnos e 2 minutos, até 3 por dia contra o
            mesmo oponente.
          </p>
        </section>
      )}
      {data && (
        <>
          <section aria-labelledby="progress-title" className="progress">
            <h2 id="progress-title">
              Você concluiu {data.done} de {data.total} desafios
            </h2>
            <progress value={data.done} max={data.total} aria-labelledby="progress-title" />
            <p className="hint">
              Cada desafio concluído paga 2 DP no fim de todo duelo. Os de vencer só contam quando o
              duelo vai até o fim: desistência e tempo esgotado não valem.
            </p>
          </section>
          <p className="choice">
            <input
              id="only-missing"
              type="checkbox"
              checked={onlyMissing}
              onChange={(event) => setOnlyMissing(event.target.checked)}
            />
            <label htmlFor="only-missing">Só os que faltam</label>
          </p>
          <ol className="challenges">
            {list.map((challenge) => (
              <li
                key={challenge.number}
                value={challenge.number}
                className={challenge.done ? "done" : undefined}
              >
                <div className="challenge-row">
                  <span>{challenge.label}</span>
                  <span className="challenge-state">
                    {challenge.done ? "Concluído" : challenge.possible ? "" : "Em breve"}
                  </span>
                </div>
              </li>
            ))}
          </ol>
        </>
      )}
    </main>
  );
}
