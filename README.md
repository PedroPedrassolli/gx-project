# GX Project

Duelos de cartas online, em tempo real: 1x1 ou em dupla, com amigos (sala com código) ou
com quem estiver na fila. As cartas, as regras e a economia (pontos por duelo, pacotes,
desafios) seguem um jogo portátil de 2008, com algumas melhorias. Só existe o modo
online, contra outras pessoas.

> **Projeto de fã, sem fins lucrativos.** Yu-Gi-Oh! é marca registrada da Konami. Este
> projeto não tem ligação com a Konami nem é aprovado por ela. Não usamos arte, música ou
> logotipos dos jogos.

**Situação:** em construção. Prontas: F0 (fundação, engine de duelo e dados do jogo), F1
(catálogo de cartas) e F2 (contas e montagem de decks). A próxima é a F3, o duelo 1x1 em
sala. No ar: https://gx-project-two.vercel.app

## Como funciona

```
React (Vercel) ──HTTP /api──▶ Rails 8 API (container na Vercel) ──FFI──▶ engine de duelo (C++ + Lua)
   │                                │
   │                                ├──▶ Postgres (Supabase, em São Paulo)
   │                                └──▶ e-mail (Brevo)
   └──▶ imagens das cartas (Cloudflare Pages)
```

A partir da F3, o tempo real dos duelos passa pelo Ably ([ADR 0002](docs/adr/0002-realtime.md)).

- **Frontend** (`frontend/`): React + Vite + TypeScript.
- **Backend** (`backend/`): Rails 8.1 em modo API. O servidor é a autoridade do duelo: cada
  jogador só recebe o que pode ver.
- **Engine de duelo**: a `ygopro-core` do Project Ignis, chamada pelo Ruby via FFI, com os
  scripts de carta do mesmo projeto ([ADR 0001](docs/adr/0001-engine.md)). O `/up/engine`
  refaz um duelo inteiro gravado para conferir que ela está no ar.
- Tudo roda em planos gratuitos, sem cartão: Vercel Hobby (funções em São Paulo), Supabase
  Free, Ably Free, Cloudflare Pages (imagens das cartas), Brevo Free (e-mail) e GitHub
  Actions em repositório público (CI e backup semanal). Os limites e quanto cada duelo gasta
  estão no [ADR 0004](docs/adr/0004-hospedagem.md).
- Contas ([ADR 0008](docs/adr/0008-contas-e-sessao.md)): cadastro a partir dos 13 anos, com
  aceite dos [termos](https://gx-project-two.vercel.app/termos) e da
  [política de privacidade](https://gx-project-two.vercel.app/privacidade), confirmação de e-mail,
  troca de senha, baixar os dados e excluir a conta (LGPD).
- Coleção e decks ([ADR 0009](docs/adr/0009-decks.md)): a conta nova ganha o deck inicial;
  o Deck Edit monta Main, Extra e Side com Destiny, valida ao vivo e importa e exporta `.ydk`.
- Catálogo em `/cartas`: o pool inteiro, com busca, filtros e o detalhe de cada carta, em
  português ou inglês. Os dados vêm da API em `/api/cards`, `/api/packs` e `/api/banlists`, com
  cache na CDN ([ADR 0007](docs/adr/0007-api-do-catalogo.md)). As imagens ficam num projeto
  só delas no Cloudflare Pages, publicado pelo workflow *Imagens das cartas*.
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

## Backup do banco

O workflow *Backup do banco* roda toda segunda: faz o `pg_dump` do banco de produção (só o
schema `public`), criptografa com a senha do secret `BACKUP_PASSPHRASE` e guarda como
artefato da Action por 30 dias. Para restaurar num Postgres local:

```bash
# 1. Baixe o artefato "banco-..." da execução que quiser (aba Actions) e descompacte o zip.
# 2. Abra com a senha do backup (a mesma do secret):
gpg --decrypt --output banco.dump banco.dump.gpg
# 3. Restaure num banco vazio:
createdb gx_restaurado
pg_restore --clean --if-exists --no-owner --dbname=gx_restaurado banco.dump
```

## Documentação

- [Especificação](docs/ESCOPO.md): regras do produto, arquitetura, fases e dados a levantar.
- [Decisões (ADRs)](docs/adr/): engine, tempo real, licença, hospedagem e planos gratuitos,
  economia, dados do jogo, API do catálogo, contas e decks.

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
