# GX Project: especificação (versão pública)

> Repo `gx-project` (público, AGPL-3.0) · Jira `GXP` · Slack `#gx-project` · Rails 8 API + React.
> Objetivo: as cartas, as regras e a economia de um jogo portátil de 2008 (aqui chamado de
> **jogo de referência**), só PvP online, com melhorias pontuais.

---

## 1. Como o jogo de referência funciona

### 1.1 Visão geral
- Saiu para PSP em 2008. Classificação PEGI 7 / CERO A.
- **3.501 cartas.** O pool vai até *Crossroads of Chaos*, inclui os dois primeiros sets de Duel Terminal e os Starter/Structure Decks anteriores a jul/2008. Tem Monstros Sincro e cartas originais do anime.
- Regras: **Master Rule (MR1)** do OCG. Banlist padrão: versão alterada da lista de março de 2008.
- Tipos de duelo: **Single, Tag e Match.** Existe duelo em rede local (com bônus próprio) e, segundo guias, troca de cartas entre jogadores.
- Fora do duelo: história com parceiros, minigames, galeria, reconhecimento de UMD, cartas e receitas por DLC. **Nada disso entra no GX Project**, exceto o que está na seção 2.

### 1.2 Sistemas
- **DP (Duel Points):** no fim de cada duelo o jogo soma **83 bônus** (Anexo A). Alguns valores:
  - derrota 10, empate 50;
  - turnos: 2 DP/turno se vencer, 1 se não;
  - vitória em Tag 50, vitória em rede 50, vitória em Match 50;
  - subir de nível 400;
  - bônus de estilo: LP baixo, vencer com exatamente 5.730 LP (573 DP), cadeias, ATK e dano máximos;
  - bônus por invocar ou usar certas cartas.
- **Nível do jogador:** dá 2 DP × nível em todo duelo e libera pacotes. **A regra de subida de nível não foi encontrada** (levantar na F0).
- **Desafios:** 104 conquistas (dano, destruição, invocações, magias e armadilhas, formas de vitória, cartas específicas, restrições de deck). Cada desafio concluído soma +2 DP em **todo** duelo.
- **Loja:**
  - pacotes de **5 cartas**, pagos em DP (o mais barato custa 50; a maioria custa 100);
  - disponibilidade de cada pacote: desde o início; num **dia fixo da semana** (que passa a ser todo dia a partir de certo nível); por **% da coleção de outro pacote**; por código secreto digitado na loja; por reconhecimento de UMD ou nota de prova.
- **Conversor de cartas:** o jogador insere de 10 a 99 cartas e recebe 1 carta aleatória do grupo que corresponde à quantidade.
- **Destiny Draw:**
  - no Deck Edit, o jogador marca cartas como *Destiny*;
  - ao usar, uma Destiny do Main Deck é sorteada e vai para o topo do deck;
  - só **uma vez por duelo por lado**, inclusive em Tag;
  - aparece quando o lado está em apuros (PV até 4000, o oponente com monstro e nenhum monstro do lado mais forte que o mais forte dele) e a situação não vira até a segunda Fase de Compra; substitui a compra normal;
  - liga e desliga nas configurações; vem ligado.
- **Deck:** Main Deck de 40 a 60 cartas, Extra Deck (Fusão/Sincro) de até 15, até 3 cópias, sujeito à banlist.
- **Tag Duel:**
  - a dupla divide 5 zonas de monstro, 5 de magia/armadilha, o cemitério, as banidas e a zona de campo;
  - Main Deck, Extra Deck e mão trocam conforme quem é o jogador da vez;
  - o LP é da dupla: 8000, configurável;
  - ordem dos turnos: A1 → B1 → A2 → B2.

### 1.3 Telas (referência)
- **Loja:** prateleira de pacotes com preço e destaque de "novo". A abertura revela carta por carta, com efeito visual por raridade.
- **Deck Edit:** baú e deck lado a lado, painel grande de detalhe da carta, filtros e ordenação, ícones de banlist, marcação de Destiny e receitas de deck.
- **Duelo:** campo em perspectiva, mão embaixo, painel de detalhe, LP dos dois lados, indicador de fase, perguntas de cadeia ("Ativar X?") e animações especiais de algumas cartas.
- **Resultado:** lista de bônus linha a linha, total de DP, subida de nível e desafios concluídos.
- **Coleção:** % completo no total e por pacote.
- **Conversor e configurações** (Destiny Draw, animações, velocidade).

---

## 2. O que muda no GX Project

| Jogo de referência | GX Project |
| --- | --- |
| História, parceiros NPC, minigames, galeria | **Removido.** Só PvP online |
| Duelo em rede local | Fila aberta + salas públicas ou privadas (código de 6 caracteres) |
| Parceiro vê a mão do companheiro (só em parte do tempo) | **Vê sempre**, inclusive no próprio turno |
| Match | Match (melhor de 3) **com Side Deck** (0 a 15 cartas) e troca entre os duelos |
| Calendário do jogo (dia da semana) | Dia da semana real, no fuso America/Sao_Paulo |
| Pacotes por UMD/nota de prova | Liberados por **desafios** equivalentes (mapeamento na F0) |
| Códigos secretos na loja | Mantidos (campo de código na loja) |
| Cartas de DLC | Entram nos pacotes ou no conversor, conforme a lista do jogo |
| Bônus de história concluída | Removido |
| Bônus de duelista (90 × nível do deck do NPC) | 90 × faixa de nível do oponente (1–10) |
| Bônus de vitória em rede | Vale em todo duelo (todo duelo é online) |
| Economia sem limite | Mesmos valores + anti-farm por cima (seção 3.5) |
| Destiny Draw nas configurações | Opção da sala; a fila segue o padrão do jogo |
| Interface, músicas e animações do jogo | **Interface original**, sons livres (CC0), animações 2D simples |

---

## 3. Regras de produto

### 3.1 Contas
- Cadastro aberto com **idade mínima de 13 anos**. A data de nascimento é pedida só para checar a idade, e é guardada só a faixa.
- Verificação de e-mail, recuperação de senha, exclusão da conta e exportação dos dados (LGPD).
- Perfil: apelido único com filtro de palavrões, avatar de uma lista fixa, nível, DP, estatísticas e desafios.
- Amigos, bloqueio e denúncia.
- Uma partida ativa por conta.

### 3.2 Cartas e coleção
- O pool é exatamente o do jogo de referência, com cartas originais do anime e Sincro (sem Sincro Sombrio).
- O texto de cada carta é o da época (pré-errata) quando existir, em inglês, ou em português quando houver tradução. A interface é em português.
- Imagens: YGOPRODeck, baixadas uma vez e hospedadas por nós, em WebP com 3 tamanhos. Cartas do anime sem imagem mostram só o texto.
- Coleção: quantidade por carta, % total e por pacote (essa % é condição de desbloqueio na loja).
- Conta nova recebe o **deck inicial do jogo de referência**.

### 3.3 Deck Edit
- Vários decks por conta, cada um com nome, Main (40–60), Extra (0–15) e Side (0–15). Até 3 cópias somando os três, respeitando a banlist e a coleção.
- Filtros: nome, tipo de carta, atributo, tipo de monstro, nível, faixa de ATK/DEF, pacote, só as novas, só as que o jogador tem. Ordenação por nome, ATK, DEF, nível, tipo e data de obtenção.
- Marcar cartas como **Destiny** (quantas quiser).
- Validação ao vivo no front e definitiva no backend. Importar e exportar em texto e no formato `.ydk`.
- No desktop, arrastar e soltar; no celular, toque com menu.

### 3.4 Loja, pacotes e conversor
- Pacotes, preço, conteúdo, raridade por carta e regra de disponibilidade **iguais ao jogo de referência** (dados levantados na F0).
- Regras de disponibilidade suportadas: sempre; dia da semana, com nível que libera todos os dias; nível mínimo; % de outro pacote; código secreto; desafio concluído. Pacote bloqueado aparece com a dica de como liberar.
- Compra de 1 ou 10 pacotes. O sorteio é feito no servidor, com semente registrada, e cada abertura fica guardada. Toda a compra roda numa transação, com chave de idempotência.
- Probabilidade por raridade: as chances do jogo de referência se a pesquisa achar; se não achar, pesos configuráveis no admin, com padrão documentado.
- **Conversor:** de 10 a 99 cartas repetidas (nunca uma carta que está num deck sem cópia sobrando) → 1 carta do grupo da quantidade, igual à tabela do jogo.

### 3.5 Economia (DP, nível e desafios)
- **DP no fim de cada duelo:** soma dos bônus do Anexo A, calculada a partir das estatísticas do duelo. A tela de resultado mostra linha por linha.
- **Nível:** a regra do jogo, se encontrada. Proposta provisória: o nível sobe a cada X DP **ganho** (não gasto), com X configurável.
- **Desafios:** os 104, avaliados no fim do duelo pelas estatísticas e pela composição do deck. O progresso fica visível no perfil.
- **Razão de DP** (`dp_transactions`): todo crédito e débito tem motivo e saldo. O saldo nunca é editado direto.
- **Anti-farm** (valores no admin): teto diário de DP vindo de salas (sugestão: 3.000); contra o mesmo oponente no mesmo dia: 100% → 50% → 25% → 0; duelo com menos de 3 turnos ou menos de 2 min só paga a derrota (10 DP); contas com menos de 7 dias têm metade do teto; limite de cadastros por IP.

### 3.6 Modos e matchmaking
| Modo | Entrada | Formato |
| --- | --- | --- |
| Fila 1x1 | Fila aberta | Single |
| Fila Tag | Sozinho ou com parceiro | Single |
| Sala 1x1 | Pública ou privada (código) | Single ou Match (com Side) |
| Sala Tag | Pública ou privada, 4 vagas | Single ou Match (com Side) |

- Opções da sala: formato, banlist (do jogo ou sem banlist), Destiny Draw ligado/desligado e tempo por turno.
- Fila: pareamento por faixa de nível, que vai abrindo com o tempo de espera. Dá para cancelar. Quem abandona várias vezes espera cada vez mais para voltar.
- Sala: revanche com um clique; o dono expulsa jogadores antes de começar. Convite de amigo chega dentro do app.
- Match: entre os duelos, 3 min para trocar o Side Deck (o deck final é validado). Quem perdeu o duelo anterior escolhe quem começa.

### 3.7 Duelo
- Regras: MR1 pela engine (seção 5.3) e a banlist escolhida.
- **Servidor autoritativo:** cada jogador recebe só o que pode ver.
- **No Tag, o parceiro vê a mão do companheiro o tempo todo.**
- Quem começa: sorteio, no formato que o jogo usa (Anexo C). Quem ganha escolhe ir primeiro ou segundo.
- Pergunta de cadeia: por padrão, o jogador só é consultado se tiver resposta possível. Configurações: "sempre perguntar" e velocidade das animações.
- Destiny Draw igual ao jogo, quando a sala permitir.
- Timer por turno e por decisão. Desistência. Reconexão com o estado completo. Desconexão vira derrota depois do prazo.
- Tempo máximo de duelo (padrão 60 min), com desempate por LP.
- Replay de todo duelo (guardado 30 dias). Botão "reportar bug de carta".
- Sem chat livre: só emotes. No Tag, há também "pings" para o parceiro (ex.: "espera", "pode atacar").

### 3.8 Admin (dentro do próprio front, por papel)
- Jogadores: busca, banimento e ajuste de DP (sempre com motivo).
- Denúncias.
- Banlists e pesos de raridade.
- Valores do anti-farm e flags (ligar/desligar fila, loja, Tag).

### 3.9 Fora do escopo
- IA e singleplayer.
- Torneios, espectador e ranking público (ficam para a v2).
- Dinheiro real.
- Chat livre.
- App nativo.
- Cartas fora do pool.
- Arte, música ou sprites do jogo.
- Troca de cartas entre jogadores (v2, talvez, com regras anti-abuso).

---

## 4. Telas (React)

| Tela | Conteúdo principal |
| --- | --- |
| Entrar / Cadastro / Senha | Formulários com verificação de idade e de e-mail |
| Lobby | Fila 1x1, Fila Tag, Salas, Loja, Deck Edit, Coleção, Conversor, Perfil, Amigos, Replays; DP e nível no topo |
| Salas | Lista das públicas, criar, entrar por código; sala de espera com vagas, deck escolhido e "pronto" |
| Deck Edit | Baú + deck (abas Main/Extra/Side) + painel da carta; filtros, Destiny, validação, importar/exportar |
| Loja | Prateleira por disponibilidade (hoje, bloqueados com dica), compra de 1 ou 10, abertura carta a carta, campo de código |
| Conversor | Escolher as repetidas, ver o grupo da quantidade e confirmar |
| Coleção | Grade com filtros, % total e por pacote |
| **Mesa de duelo** | Campo MR1 dos dois lados (5 + 5 + campo + cemitério + deck + extra + banidas). Mão em leque. Painel de detalhe. LP e fases (DP/SP/M1/BP/M2/EP). Pilha da cadeia. Log. Timer. Emotes. Botão do Destiny Draw. Desistir. No Tag: mão do parceiro e indicador de quem joga |
| Prompts do duelo | Um componente por tipo de pergunta da engine (seção 5.3) |
| Resultado | Bônus linha a linha, total de DP, subida de nível, desafios novos; revanche, replay, reportar |
| Side Deck (Match) | Troca entre Main e Side com timer de 3 min |
| Perfil / Desafios | Nível, estatísticas, lista dos 104 desafios com progresso |
| Replays | Player com linha do tempo (avançar, voltar, pular para o turno) |
| Configurações | Animações, pergunta de cadeia, som, idioma do texto das cartas |
| Admin | Seção 3.8 |
| Legais | Termos, privacidade, aviso de fã, créditos, código-fonte |

- Layout: desktop e celular na horizontal (no celular na vertical, melhor esforço).
- Acessibilidade: dá para jogar só com teclado, o contraste é AA e o log é lido por leitor de tela.

---

## 5. Arquitetura

### 5.1 Visão
```
React (Vercel) ──HTTP /api──▶ Rails 8 API (container na Vercel) ──FFI──▶ ygopro-core + scripts Lua
      ▲                            │            │
      └──── Ably (canal privado) ◀─┘            └──▶ Postgres (Supabase) · Blob (backup) · Brevo (e-mail)
```
- **Imagens das cartas:** Cloudflare Pages, direto para o navegador (ADR 0004).
- **Mesmo domínio:** o `vercel.json` repassa `/api/*` para o Rails, então o cookie de sessão é do próprio site.
- **Sem worker:** o pareamento acontece quando alguém entra na fila; o timeout é cobrado pelo oponente (o front dele chama a API depois do prazo); limpezas rodam numa Action agendada.

### 5.2 Módulos do backend (POROs simples, um por arquivo)
- **Contas:** `Accounts` (cadastro, sessão, verificação, LGPD, idade); `Social` (amigos, bloqueio, denúncia).
- **Cartas e decks:** `Catalog` (cartas, pacotes, banlists, grupos do conversor, deck inicial, desafios e tabela de bônus; dados versionados em `db/seeds/*.yml`); `Decks` (`DeckValidator`, importação/exportação).
- **Economia:** `Economy::Ledger` (débito e crédito atômicos); `BonusCalculator` (puro: estatísticas → linhas de bônus); `LevelService`; `ChallengeEvaluator`; `AntiFarm`.
- **Loja:** `Shop::Availability` (dia, nível, %, código, desafio); `Shop::PackOpener` (sorteio com semente); `Shop::Converter`.
- **Partidas:** `Matchmaking::Queue`, `Matchmaking::Rooms`.
- **Duelo:** `Duel::Engine` (wrapper FFI); `Duel::Session` (reconstrói pelo replay; cache LRU no processo); `Duel::MessageParser` (bytes → eventos tipados); `Duel::ViewProjector` (visão por jogador, com a mão do parceiro no Tag); `Duel::ResponseGuard` (sequência e formato); `Duel::StatsCollector` (alimenta bônus e desafios); `Duel::Timeouts`.
- **Realtime:** interface `Publisher` com `AblyPublisher` (produção) e `MemoryPublisher` (dev e CI), e o endpoint de token.
- **Ops:** relatório de bug → Jira + Slack; tarefas de limpeza.

### 5.3 Engine
- Fonte: `ygopro-core` do Project Ignis (fork do edo9300) + `CardScripts`, fixados num commit e compilados no `Dockerfile.vercel`. O banco das cartas da engine (`BabelCDB`, em SQLite) entra junto, só como referência (ver o ADR da engine).
- Ruby chama a engine via `ffi`, com as funções `OCG_CreateDuel`, `OCG_DuelNewCard`, `OCG_StartDuel`, `OCG_DuelProcess`, `OCG_DuelGetMessage`, `OCG_DuelSetResponse`, `OCG_DuelQuery*` e `OCG_DestroyDuel`.
- Modo de regra: **MR1**. Tag pelo suporte nativo de times da engine.
- Destiny Draw: um script Lua de regra carregado no início do duelo. A escolha do jogador vira uma resposta registrada, o que mantém o replay determinístico.
- **Estado = semente + decks + lista de respostas.** Cada ação reconstrói o duelo pelo replay, com cache em memória quando a instância está quente. Meta: < 300 ms no p95.
- Perguntas da engine que viram prompt na tela (lista fechada pelo header fixado): `SELECT_IDLECMD`, `SELECT_BATTLECMD`, `SELECT_CHAIN`, `SELECT_EFFECTYN`, `SELECT_YESNO`, `SELECT_OPTION`, `SELECT_CARD`, `SELECT_UNSELECT_CARD`, `SELECT_TRIBUTE`, `SELECT_SUM`, `SELECT_PLACE`, `SELECT_DISFIELD`, `SELECT_POSITION`, `SELECT_COUNTER`, `SORT_CARD`, `SORT_CHAIN`, `ANNOUNCE_RACE`, `ANNOUNCE_ATTRIB`, `ANNOUNCE_CARD`, `ANNOUNCE_NUMBER`, `ROCK_PAPER_SCISSORS`.

### 5.4 Fluxo de uma ação
1. O front envia `POST /api/matches/:id/responses` com `{seq, resposta}`.
2. O Rails trava a partida (`SELECT … FOR UPDATE`) e confere o `seq`.
3. `Duel::Session` reconstrói o duelo (ou usa o cache), aplica a resposta e processa até a próxima pergunta.
4. A resposta é gravada em `match_responses`. O `ViewProjector` gera a visão de cada jogador, e o `Publisher` manda **uma mensagem por jogador** com os eventos agrupados.
5. Se o duelo acabou, os bônus, o nível, os desafios e o DP são calculados e creditados numa transação.

### 5.5 Contrato do realtime
- Um canal por jogador: `private:user:{id}`. O token do Ably, emitido pelo Rails, só permite assinar esse canal.
- Eventos: `match.found`, `room.updated`, `invite.received`; `duel.delta` (`seq`, `events[]`, `prompt?`, `timers`); `duel.ended` (resultado + bônus).
- Se faltar um `seq` no meio, o front chama `GET /api/matches/:id/state` e continua de lá.
- O cliente só abre a conexão dentro de fila, sala ou duelo, e fecha depois de 2 min com a aba oculta. Se o Ably estourar o limite, o front cai para polling a cada 2 s.

### 5.6 API (REST JSON, prefixo `/api`)
- **Contas:** `session`, `registrations`, `passwords`, `me` (+ `export`, `destroy`).
- **Social:** `friends`, `blocks`, `reports`.
- **Cartas e decks:** `cards` (com busca e filtros), `collection`, `decks` (CRUD + `validate`, `import`, `export`).
- **Loja:** `shop/packs` (disponibilidade de hoje), `shop/purchases`, `shop/codes`, `converter`.
- **Partidas:** `queue` (entrar, sair); `rooms` (CRUD, `join`, `ready`, `kick`); `matches/:id` (`state`, `responses`, `timeout_claim`, `surrender`, `side_deck`, `replay`, `bug_report`).
- **Outros:** `realtime/token`, `challenges`, `profile/:apelido`, `admin/*`.

### 5.7 Modelo de dados
- **Contas:** `users` (email, apelido, faixa_idade, nível, dp_ganho_total, role, banned_at); `friendships`, `blocks`, `reports`.
- **Catálogo:** `cards` (passcode, nomes, textos, tipo, atributo, raça, nível, atk, def, flags); `packs` (nome, preço, regra_disponibilidade jsonb, ordem); `pack_cards` (raridade, peso); `banlists` + `banlist_entries`; `converter_groups` + `converter_group_cards`; `challenges`, `bonus_rules` (seed YAML).
- **Coleção:** `collections` (user, card, qtd, obtida_em); `decks` + `deck_cards` (secao main/extra/side, destiny bool); `user_challenges`.
- **Economia:** `dp_transactions` (motivo, valor, saldo_apos, ref polimórfica), `pack_openings` (semente, cartas).
- **Partidas:** `rooms` (código, pública, modo, formato, opções jsonb); `queue_entries`; `matches` (sala, modo, formato, semente, status, vencedor, duel_no, iniciado/terminado); `match_players` (time, posição, deck snapshot jsonb); `match_responses` (seq, player, bytes); `match_stats` (jsonb por jogador).

### 5.8 Front
- React + Vite + TypeScript. React Router. TanStack Query para os dados da API.
- O estado do duelo fica num `useReducer` que aplica os `duel.delta` em ordem de `seq`.
- Imagens: miniatura na lista, normal no campo, grande no zoom. Lazy load. As cartas do próprio deck são pré-carregadas antes do duelo.
- Animações 2D com CSS e a Web Animations API, com controle de velocidade.

### 5.9 Planos gratuitos (conferidos na F0: ADR 0004)
| Serviço | Uso | Limite que importa |
| --- | --- | --- |
| Vercel Hobby | Front + API em container, em São Paulo (`gru1`) | 1 M de invocações e 4 h de CPU por mês; prévias desligadas |
| Supabase Free | Postgres, em São Paulo (`sa-east-1`) | 500 MB de banco, 5 GB de saída; pausa após 7 dias sem uso (o `uptime.yml` chama `/up/db`); **sem backup** |
| Ably Free | Realtime | 6 M mensagens/mês, 200 conexões, 200 canais, 500 msg/s, 64 KiB por mensagem |
| Cloudflare Pages | Imagens das cartas | 20 mil arquivos; banda sem limite |
| Vercel Blob | Backup | 1 GB; 2 mil uploads por mês |
| Brevo Free | E-mail | 300 por dia; sem domínio próprio, o remetente sai como `@brevosend.com` |
| Sentry Developer | Erros | 5 mil erros por mês |
| GitHub Actions | CI | Sem limite em repo público |

O resumo semanal mostra o uso de cada serviço e avisa quando passa de 80%. O Cloudflare R2
saiu na conferência: pede cartão para ativar e cobra o excedente (ADR 0004).

---

## 6. Qualidade
- **Testes:** backend com Minitest (POROs, requests e transações de DP/loja); **contrato da engine** (duelos roteirizados com semente fixa → estado esperado, com um teste por mecânica: MR1, Fusão, Ritual, Sincro, Tag, Destiny Draw, Match/Side); um teste por bônus do Anexo A e por desafio; front com funções puras (reducer do duelo, filtros, validação) e Playwright + axe com 2 navegadores (1x1) e 4 (Tag).
- **Segurança:** Brakeman e bundler-audit; Rack::Attack; cookie `SameSite` + token CSRF; sorteios e informação oculta só no servidor; segredos só nos painéis.
- **Desempenho:** p95 de ação < 300 ms; uma mensagem por jogador por ação; replay de 30 dias.
- **Backup:** `pg_dump` semanal, criptografado, salvo no Vercel Blob (ADR 0004).
- **Documentação:** README e CONTRIBUTING em português. ADRs em `docs/` sobre engine, realtime, AGPL, hospedagem e economia.

## 7. Integrações e automações
- **GitHub:** CI, `dependabot.yml`, template de PR, `auto-merge.yml`, `jira.yml`, `uptime.yml` (a cada 4 h), backup semanal e limpeza diária.
- **Vercel:** Hobby, prévias desligadas, `ignoreCommand`.
- **Jira:** um épico por fase e um card por PR, com transições automáticas.
- **Slack:** `#gx-project` com o CI da `main`, PRs e bugs de carta.
- **Figma/FigJam:** diagrama de arquitetura; telas do duelo, da loja e do Deck Edit antes da F3.
- **Resumo semanal** agendado, incluindo o uso dos planos gratuitos.

## 8. Fases
| Fase | Entrega | Pronto quando |
| --- | --- | --- |
| F0 Fundação e dados | Esqueleto, CI, deploy. Spikes: engine via FFI (MR1, Tag, Destiny Draw), tempo do replay, Ably. **Levantamento completo dos dados do jogo** (Anexo B) | Duelo headless com semente; dados em YAML; lista do que falta |
| F1 Catálogo | Importador, imagens no Cloudflare Pages, banlists, busca | Pool inteiro com imagem ou só texto |
| F2 Contas e Deck Edit | Contas, LGPD, deck inicial, coleção, Deck Edit completo | Montar e validar deck com Side e Destiny |
| F3 Duelo 1x1 em sala | Salas, mesa, todos os prompts, timer, reconexão, replay | 1x1 completo sem travar |
| F4 Economia e loja | Bônus, nível, desafios, loja, conversor, anti-farm | Resultado mostra os bônus e o DP compra pacote |
| F5 Fila + Match | Fila 1x1, Match com Side | Pareamento em < 30 s com gente na fila |
| **MVP / beta aberto** | | |
| F6 Tag | Salas e fila 2x2, mão do parceiro, pings | Tag completo, inclusive em Match |
| F7 Social e acabamento | Amigos, convites, replays, admin, acessibilidade, celular | Lighthouse/axe sem erro crítico |

## 9. Backlog da F0
1. `GXP-1` Esqueleto: backend, frontend, CI, Vercel, LICENSE AGPL-3.0, `/up` e `/up/db`.
2. `GXP-2` Compilar `ygopro-core` + Lua no container e chamar via FFI (duelo headless com MR1 e semente).
3. `GXP-3` Replay a cada ação + cache LRU; medir o p95.
4. `GXP-4` Tag e Destiny Draw na engine (script de regra).
5. `GXP-5` Spike do Ably: token de assinatura, canal privado, `MemoryPublisher`.
6. `GXP-6` Levantar os dados do jogo (Anexo B) em YAML, com fonte por item.
7. `GXP-7` Cruzar o pool com os scripts e as imagens; gerar a lista do que falta.
8. `GXP-8` Validar os limites gratuitos e escrever os ADRs.

## 10. Riscos técnicos
| Risco | Nível | Mitigação |
| --- | --- | --- |
| Dados do jogo incompletos (regra de nível, chances dos pacotes, condição do Destiny Draw) | Médio | Pesquisa na F0 + conferência (Anexo C) + valores configuráveis |
| Cartas sem script ou sem imagem | Médio | Lista na F0; escrever o script em Lua ou tirar do pool |
| Fidelidade da MR1 na engine | Médio | Testes de contrato por mecânica |
| Limites gratuitos | Médio | Seção 5.9, medição e plano B (VM Oracle Always Free com Action Cable; ela pede cartão, então é decisão do Pedro) |
| Farm de DP | Médio | Anti-farm (3.5) |
| LGPD | Médio | 13+, exclusão e exportação, coleta mínima |
| Tamanho (a F3 é a maior fase) | Alto | MVP antes do Tag |

## 11. Decisões
| # | Decisão |
| --- | --- |
| 1 | Repo público AGPL-3.0 |
| 2 | Engine do Project Ignis (MR1 + pré-errata) |
| 3 | Ably para realtime; Supabase só para o banco |
| 4 | Fila aberta + salas públicas ou privadas |
| 5 | GX Project / `GXP` |
| 6 | Cartas, regras e economia do jogo de referência, com as mudanças da seção 2 |
| 7 | Parceiro vê a mão do companheiro sempre |
| 8 | Match com Side Deck |
| 9 | Idade mínima de 13 anos |

---

## Anexo A: bônus de DP (83) e adaptação
Fonte: Yugipedia (página de bônus e desafios do jogo de referência). Fórmulas com divisão arredondam para baixo.

| # | Bônus | DP | GX Project |
| --- | --- | --- | --- |
| 01 | Histórias concluídas | 2 × n | **Removido** |
| 02 | Nível | 2 × nível | Igual |
| 03 | Desafios | 2 × concluídos | Igual |
| 04 | Derrota | 10 | Igual |
| 05 | Empate | 50 | Igual |
| 06 | Turnos | 2/turno se vencer, 1 se não | Igual |
| 07 | Vitória em Tag | 50 | Igual |
| 08 | Vitória em rede | 50 | Vale em toda vitória |
| 09 | Vitória em Match | 50 | Igual |
| 10 | Subir de nível | 400 | Igual |
| 11 | Duelista (nível do deck do NPC) | 90 × nível do deck | 90 × faixa do oponente (1–10) |
| 12 | Oponente sem cartas para comprar | 20 | Igual |
| 13–23 | Formas de vencer | Rápida em ≤ 5 turnos 10 · virada 20 · no turno do oponente 20 · no turno do parceiro 10 · LP < 1000 20 · LP < 100 100 · sem sofrer dano 10 · LP > 20.000 100 · exatamente 5.730 LP 573 · deck < 10 20 · deck = 0 100 | Igual |
| 24–31 | Uso de cartas | 10+ magias 2/magia · 10+ armadilhas 2/armadilha · sem magias 15 · sem armadilhas 15 · Fusão 4/cada · Ritual 4/cada · Tributo 4/cada · sem invocação especial 10 | Igual |
| 32–36 | Picos | Cadeia ≥ 3: 2 × maior elo · ATK ≥ 3000: ATK/500 · dano de um ataque ≥ 3000: dano/250 · desvantagem ≥ 5000 de LP: diferença/250 · dano refletido: 1 a cada 100 | Igual |
| 37–39 | Tipo de dano | LP exatamente 0 10 · só dano de batalha 10 · só dano de efeito 30 | Igual |
| 40–45 | 10+ cartas | Destruir em batalha / destruir por efeito / remover / descartar da mão / descartar do deck / devolver à mão: 4 por carta | Igual |
| 46–52 | Diversos | Sorte em moeda/dado 2 por acerto seguido · marcadores de magia ≥ 5: 4 por marcador · União 6 · 3 cópias da mesma carta no campo 5 · todas as zonas de monstro 10 · nenhuma zona de monstro livre para o oponente 60 · carta-chave do oponente 20 | Igual |
| 53–57 | Vitórias especiais | Exodia 50 · Destiny Board 100 · Final Countdown 50 · Last Turn 50 · Skull Servant 1 | Igual |
| 58–71 | Invocou carta específica | 10 a 30 (lista na fonte) | Igual |
| 72–82 | Usou carta específica | 5 a 30 (lista na fonte) | Igual |
| 83 | New Bonus | 30 | Condição a descobrir; sem ela, fica desligado |

## Anexo B: dados a levantar na F0 (com fonte por item)
1. Lista das 3.501 cartas, com os passcodes, incluindo as do anime e de DLC.
2. Todos os pacotes: nome, preço, cartas e raridade por carta, regra de disponibilidade (dia, nível, %, código, UMD/nota). Páginas de cada pacote do jogo no Yugipedia.
3. Chances por raridade dentro do pacote, se existir fonte.
4. Deck inicial.
5. Tabela do conversor de cartas (grupo por quantidade).
6. Os 104 desafios com as condições.
7. Regra de subida de nível.
8. Banlist padrão.
9. Condição exata do Destiny Draw e se ele vem ligado por padrão. Feito: regra pela Yugipedia (ADR 0001); ligado por padrão, confirmado pelo Pedro.
10. LP do Tag Duel. Feito: 8000, configurável, confirmado pelo Pedro.

Fontes: Yugipedia (CC BY-SA, dar crédito), guias do GameFAQs e Supercheats (só para conferir), YGOPRODeck (dados e imagens), BabelCDB/CardScripts (passcodes e scripts).

## Anexo C: conferência de memória do jogo
- [ ] Como se decide quem começa (cara ou coroa, ou pedra-papel-tesoura)?
- [x] Quando o botão de Destiny Draw aparece? Segue a regra do jogo (pesquisada: em apuros com PV até 4000, até a segunda Fase de Compra).
- [x] LP da dupla no Tag (8000?) Sim, 8000, configurável.
- [x] Destiny Draw vem ligado por padrão? Sim.
- [ ] O layout das telas (seção 1.3) bate com o que você lembra? Algo marcante ficou de fora?
- [ ] O que cada pacote de UMD/nota de prova deve exigir aqui?
