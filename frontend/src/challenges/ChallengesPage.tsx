import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { useSession } from "../account/session.ts";
import { request } from "../api.ts";
import { SignInFirst } from "../PageNotice.tsx";
import { usePageTitle } from "../pageTitle.ts";

type Challenge = { number: number; label: string; done: boolean; possible: boolean };
type Challenges = { done: number; total: number; challenges: Challenge[] };

// Os desafios (escopo 3.5; GXP-88): os 104 do jogo, na ordem, com os concluídos marcados.
// Cada um conta uma vez, e cada desafio concluído paga 2 DP em todo duelo.
export function ChallengesPage() {
  usePageTitle("Desafios");
  const session = useSession();
  const user = session.data?.user;
  const [onlyMissing, setOnlyMissing] = useState(false);
  const challenges = useQuery({
    queryKey: ["challenges"],
    queryFn: async () => (await request<{ data: Challenges }>("GET", "/api/challenges")).data,
    enabled: Boolean(user),
  });

  if (session.isSuccess && !user) {
    return <SignInFirst title="Desafios" reason="para ver os seus desafios" />;
  }
  const data = challenges.data;
  const list = data?.challenges.filter((challenge) => !onlyMissing || !challenge.done) ?? [];

  return (
    <main className="page narrow">
      <h1>Desafios</h1>
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
                <span>{challenge.label}</span>
                <span className="challenge-state">
                  {challenge.done ? "Concluído" : challenge.possible ? "" : "Em breve"}
                </span>
              </li>
            ))}
          </ol>
        </>
      )}
    </main>
  );
}
