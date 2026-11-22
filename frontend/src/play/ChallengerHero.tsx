import { Link } from "react-router";
import { CardImage } from "../catalog/CardImage.tsx";
import type { CardSummary } from "../catalog/cards.ts";
import { nextCharacter, type Character } from "../characters/api.ts";

// O próximo personagem a vencer, com a carta dele (o prêmio da primeira vitória), no Início e
// em Jogar. friends: o atalho para as salas (Jogar já tem as salas logo embaixo).
export function ChallengerHero({
  characters,
  friends = true,
}: {
  characters: Character[] | undefined;
  friends?: boolean;
}) {
  // Enquanto a lista chega, o lugar do destaque fica reservado (a página não pula).
  if (!characters) return <div className="home-hero loading" aria-hidden="true" />;
  const next = nextCharacter(characters);
  if (!next) {
    return (
      <section className="home-hero" aria-labelledby="hero-title">
        <div>
          <h2 id="hero-title">Você venceu todos os personagens</h2>
          <p className="muted">Dá para duelar de novo contra qualquer um, ou chamar os amigos.</p>
          <p className="actions">
            <Link className="cta" to="/jogar">
              Jogar
            </Link>
          </p>
        </div>
      </section>
    );
  }
  const card: CardSummary | undefined = next.signature;
  return (
    <section className="home-hero" aria-labelledby="hero-title">
      {card && <CardImage card={card} size="m" width={268} height={391} className="hero-card" />}
      <div>
        <h2 id="hero-title">Próximo desafiante: {next.name}</h2>
        <p className="muted">{next.description}</p>
        {card && (
          <p className="hero-prize">A primeira vitória dá a carta {card.name_pt ?? card.name}.</p>
        )}
      </div>
      <p className="actions hero-actions">
        <Link className="cta" to={`/personagens?duelar=${next.id}`}>
          Duelar contra {next.name}
        </Link>
        {friends && (
          <Link className="cta secondary" to="/salas">
            Duelar com amigos
          </Link>
        )}
      </p>
    </section>
  );
}
