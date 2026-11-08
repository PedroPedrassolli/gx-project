import { currentPhase, PHASES } from "./roadmap.ts";

// A AGPL pede que quem usa o site pela rede consiga baixar o código-fonte.
const SOURCE_URL = "https://github.com/PedroPedrassolli/gx-project";

export function App() {
  const phase = currentPhase(PHASES);

  return (
    <main className="page">
      <header>
        <p className="eyebrow">Projeto de fã, sem fins lucrativos</p>
        <h1>GX Project</h1>
        <p className="lead">
          Duelos de cartas online, em tempo real, com amigos ou com quem estiver na fila.
        </p>
      </header>

      <p>
        <a className="cta" href="/cartas">
          Ver o catálogo de cartas
        </a>
      </p>

      <section aria-labelledby="status-title">
        <h2 id="status-title">Em construção</h2>
        <p>{phase ? `Fase atual: ${phase.code}, ${phase.name}.` : "Todas as fases terminaram."}</p>
        <ol className="phases">
          {PHASES.map((item) => (
            <li key={item.code} aria-current={item === phase ? "step" : undefined}>
              <span className="code">{item.code}</span> {item.name}
            </li>
          ))}
        </ol>
      </section>

      <footer>
        <p>
          Yu-Gi-Oh! é marca registrada da Konami. Este projeto não tem ligação com a Konami nem é
          aprovado por ela.
        </p>
        <p>
          <a href={SOURCE_URL}>Código-fonte</a> sob a licença AGPL-3.0.
        </p>
      </footer>
    </main>
  );
}
