# GX Project

Duelos de cartas online, em tempo real: 1x1 ou em dupla, com amigos (sala com código) ou
com quem estiver na fila. As cartas, as regras e a economia (pontos por duelo, pacotes,
desafios) seguem um jogo portátil de 2008, com algumas melhorias. Só existe o modo
online, contra outras pessoas.

> **Projeto de fã, sem fins lucrativos.** Yu-Gi-Oh! é marca registrada da Konami. Este
> projeto não tem ligação com a Konami nem é aprovado por ela. Não usamos arte, música ou
> logotipos dos jogos.

**Situação:** em construção, na fase F0 (fundação, engine de duelo e levantamento dos dados).

## Como funciona

```
React (Vercel) ──HTTP /api──▶ Rails 8 API (container na Vercel) ──FFI──▶ engine de duelo (C++ + Lua)
                                    │
                                    └──▶ Postgres (Supabase)
```

- **Frontend** (`frontend/`): React + Vite + TypeScript.
- **Backend** (`backend/`): Rails 8.1 em modo API. O servidor é a autoridade do duelo: cada
  jogador só recebe o que pode ver.
- **Engine de duelo**: a `ygopro-core` do Project Ignis, chamada pelo Ruby via FFI, com os
  scripts de carta do mesmo projeto ([ADR 0001](docs/adr/0001-engine.md)). O `/up/engine`
  refaz um duelo inteiro gravado para conferir que ela está no ar.
- Tudo roda em planos gratuitos, sem cartão: Vercel Hobby (funções em São Paulo), Supabase
  Free, Ably Free e GitHub Actions em repositório público. Os limites e quanto cada duelo
  gasta estão no [ADR 0004](docs/adr/0004-hospedagem.md).
- Catálogo em `/cartas`: o pool inteiro, com busca, filtros e o detalhe de cada carta, em
  português ou inglês. Os dados vêm da API em `/api/cards`, `/api/packs` e `/api/banlists`, com
  cache na CDN ([ADR 0007](docs/adr/0007-api-do-catalogo.md)).
- Licença AGPL-3.0: quem usa o site pela rede tem direito ao código ([ADR 0003](docs/adr/0003-agpl.md)).

## Rodar no seu computador

Precisa de Ruby 3.3, Postgres 16, Node 24 e, para compilar a engine, g++, meson e ninja.

```bash
# A engine, os scripts e os dados das cartas são submódulos
git clone --recurse-submodules --shallow-submodules https://github.com/PedroPedrassolli/gx-project

# Backend (porta 3000)
cd backend
bin/setup            # instala as gems, compila a engine e prepara o banco
bin/rails test       # testes, com cobertura mínima de 100%

# Frontend (porta 5173; /api e /up vão para o Rails)
cd frontend
npm ci
npm run dev
npm test             # testes unitários
npm run test:e2e     # navegador + acessibilidade (axe)
```

## Documentação

- [Especificação](docs/ESCOPO.md): regras do produto, arquitetura, fases e dados a levantar.

## Contribuir

O fluxo (card no Jira → branch → PR pequeno → CI → merge automático), os comandos e as
armadilhas conhecidas estão no [CONTRIBUTING.md](CONTRIBUTING.md).

## Licença e créditos

[AGPL-3.0](LICENSE). Se você rodar uma versão modificada num servidor, precisa oferecer o
código-fonte a quem usa (o site tem o link no rodapé).

- Engine: [ygopro-core](https://github.com/edo9300/ygopro-core) (edo9300, AGPL-3.0).
- Scripts das cartas: [CardScripts](https://github.com/ProjectIgnis/CardScripts) (Project Ignis, AGPL-3.0).
- Dados das cartas para a engine: [BabelCDB](https://github.com/ProjectIgnis/BabelCDB) (Project
  Ignis), usado só como submódulo; os dados não ficam neste repositório.
