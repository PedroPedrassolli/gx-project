# Como contribuir

Leia o `README.md` para a visão geral. Este arquivo resume o que você precisa saber para
mudar o projeto sem quebrar nada.

## O projeto

- **Rails 8.1 em modo API** (`backend/`, Postgres) + **React com Vite e TypeScript**
  (`frontend/`), publicados juntos na Vercel (Vercel Services: site estático + Rails em
  container).
- O código precisa continuar **simples, legível para um dev júnior**: POROs pequenos, nomes
  em inglês, comentários e documentação em português explicando o porquê. Nada de
  abstração "para o futuro".
- **Testes primeiro** para a engine, a economia, a loja e a validação de deck. Nada entra
  na `main` sem teste.

## Fluxo de trabalho (obrigatório)

1. Card no Jira (projeto **GXP**, `pedrassolli.atlassian.net`).
2. Branch `gxp-N-descricao` a partir da `main` → o card vai para "Em andamento".
3. PR pequeno (menos de 400 linhas úteis), com o título começando por `GXP-N:` → "Em análise".
4. **Merge automático** (`.github/workflows/auto-merge.yml`): entra sozinho quando a CI
   passa no commit atual e o PR está atualizado com a `main`. Rótulo `segurar` ou rascunho
   seguram. Depois do merge o card vai para "Concluído".

## Comandos

| Pasta | Comando | Para quê |
| --- | --- | --- |
| `backend` | `bin/build-engine` | Compila a engine de duelo (precisa de g++, ninja e meson ≥ 1.12, do PyPI) |
| `backend` | `bin/rails test` | Testes (cobertura mínima de 100%) |
| `backend` | `bin/rubocop` / `bin/brakeman` / `bin/bundler-audit` | Estilo e segurança |
| `backend` | `bin/rails duel:record_health_check` | Grava de novo o duelo do `/up/engine` (depois de atualizar a engine ou os scripts) |
| `backend` | `bin/rails "duel:benchmark[200]"` | Mede aqui a ação fria e a quente, como o `/up/engine` |
| `backend` | `bin/rails dados:jogo` | Baixa de novo da Yugipedia os dados do jogo para `db/seeds/jogo` (uns 3 minutos; veja o README da pasta) |
| `frontend` | `npm test` / `npm run lint` / `npm run typecheck` / `npm run format:check` | Unitários, ESLint, tipos e Prettier |
| `frontend` | `npm run test:e2e` | Playwright + axe contra o build de produção |

## Planos gratuitos (não estourar é obrigatório)

- **GitHub Actions:** repositório público, minutos sem limite. Mesmo assim, todo job tem
  `timeout-minutes` e um push novo cancela a execução anterior.
- **Vercel Hobby:** só uso pessoal e não comercial. Prévias desligadas
  (`git.deploymentEnabled`) e `scripts/vercel-ignorar-build.sh` (no *Ignored Build Step* do
  projeto, não no `vercel.json`) só publica quando muda o que vai para o ar. Cada deploy guarda a imagem do container (Function Storage, 10 GB na conta
  toda): evite pushes desnecessários e gems que não são usadas.
- **Jira Free:** sem regras de automação (150 passos/mês). Os cards andam pelo `jira.yml`.
- Antes de usar um serviço novo, confira o limite do plano gratuito e escreva a conta do
  custo mensal no PR. Nunca deixe ligada uma cobrança por excedente. Os limites conferidos
  e o gasto por duelo estão no [ADR 0004](docs/adr/0004-hospedagem.md).
- **Licença:** contribuição entra como AGPL-3.0. Dependência nova só com licença compatível
  (MIT, BSD, ISC, Apache-2.0, MPL-2.0, LGPL, GPL-3.0 ou AGPL-3.0), conferida no PR
  ([ADR 0003](docs/adr/0003-agpl.md)).

## Armadilhas conhecidas

- **Engine em submódulos** (`backend/vendor/engine/`): clone com `--recurse-submodules` ou rode
  `git submodule update --init --recursive --depth 1`. Atualizar a engine, os scripts ou o
  BabelCDB é sempre um PR à parte, com os testes de contrato passando (ADR 0001).
- **A engine não embaralha o deck no começo**: a partida embaralha e guarda a ordem. Sem
  isso, o replay não sai igual.
- **`aux.Stringid(código, n)` é `código << 20 | n`** (utility.lua): é o número que chega na
  descrição das perguntas, como a do Destiny Draw.
- **Marcador de pular a CI** (colchetes + `skip ci`) em **qualquer** mensagem de commit pula a
  CI de push e de pull request. Nunca cite o marcador em commits nem no corpo do PR.
- **Merge pelo `GITHUB_TOKEN` não dispara workflows**: por isso o `auto-merge.yml` move o
  card do Jira sozinho.
- Workflows disparados por `workflow_run` ou `status` só usam a versão que está na `main`.
- **Actions fixadas pelo SHA do commit**, com a versão num comentário. Não troque por `@v7`:
  uma tag pode ser movida para outro código. O Dependabot atualiza o SHA e o comentário juntos.
- **`overrides` no `frontend/package.json`**: força o `minimatch` 11 (alerta
  GHSA-g3hv-75wg-m249) enquanto o ESLint ainda pede o 10. Quando o ESLint passar a pedir o
  11 (`npm view eslint dependencies.minimatch`), apague o override.
- **Rodapé automático**: o `rodape-pr.yml` tira sozinho do corpo de PRs e comentários o
  rodapé que ferramentas acrescentam ao criar o texto pela API.
- **Segredos** (`SECRET_KEY_BASE`, `DATABASE_URL`, `ABLY_API_KEY`, tokens) ficam só nos painéis da
  Vercel e do GitHub. Nunca no repositório, em issue ou em PR. Sem a `ABLY_API_KEY`, os eventos
  de tempo real ficam na memória (ADR 0002).
- Não apague dados permanentemente (branches, issues, cards, imagens, deploys) sem o Pedro pedir.
