# ADR 0001: engine de duelo

- **Data:** 06/11/2026
- **Situação:** aceita (GXP-2). Cache e números da Vercel no GXP-3; Tag e Destiny Draw no
  GXP-4; regra do Destiny Draw revista no GXP-20 (07/11/2026).

## Contexto

As regras do duelo (MR1, cadeias, Fusão, Ritual, Sincro, Tag) e os efeitos de milhares
de cartas não cabem num projeto pessoal se forem escritos do zero. Precisamos de uma engine
madura, que rode no servidor (o servidor é a autoridade do duelo) e que dê para chamar a
partir do Rails.

## Decisão

1. **Engine:** `ygopro-core` do edo9300 (a usada pelo EDOPro/Project Ignis), AGPL-3.0, com os
   scripts de carta do **CardScripts** (Project Ignis, AGPL-3.0). É o mesmo ecossistema que já
   tem as versões pré-errata e as cartas do anime.
2. **Como entra no projeto:** submódulos fixados num commit, em `backend/vendor/engine/`:

   | Submódulo | Commit fixado |
   | --- | --- |
   | `ygopro-core` (com a Lua como submódulo dele) | `c2e0b697e031d3560c077c9cd2cc76474969dedf` |
   | `CardScripts` | `915c6ff63518a04e18d16ee45962d75a8c8be264` |
   | `BabelCDB` | `5b6b23d9fed8d11983dc8272bff7a21a12cfbf5e` |

   Atualizar é sempre um PR à parte (o Dependabot abre um por mês), que só entra com os
   testes de contrato passando.
3. **BabelCDB sem licença:** o repositório do BabelCDB não declara licença, então os dados
   ficam com todos os direitos reservados ao autor. Por isso ele entra **só como submódulo**:
   o nosso repositório guarda o endereço e o commit, não os dados. Os arquivos `.cdb` só são
   copiados para a imagem do container na Vercel, que não é distribuída. Decisão do Pedro em
   06/11/2026. Os textos e nomes que o jogador vê (F1) virão de fontes com licença clara
   (Yugipedia, CC BY-SA, com crédito).
4. **Chamada:** a engine é compilada como biblioteca compartilhada (`bin/build-engine`, com
   meson e ninja) e o Ruby chama via **FFI** (`app/services/duel/native.rb`). Nada de
   processo separado nem de worker.
5. **Regras:** `DUEL_MODE_MR1` (853760). Os números que o Ruby usa (modo, locais, mensagens,
   as 21 perguntas) são conferidos contra o header fixado pelo teste
   `test/services/duel/constants_test.rb`.
6. **Embaralhamento:** a engine **não** embaralha os decks no começo do duelo (quem hospeda
   embaralha antes de adicionar as cartas, como o EDOPro faz). Então quem cria a partida
   embaralha e **guarda a ordem**. O replay não depende de nenhum algoritmo de embaralhar.
7. **Estado = semente + decks na ordem + respostas.** Refazer o duelo com isso dá exatamente
   as mesmas mensagens (conferido em teste).
8. **Pergunta de cadeia sem opção:** num duelo, a maior parte das respostas é "não encadear"
   numa janela sem carta para ativar. O servidor responde essas sozinho (e registra a
   resposta), em vez de perguntar ao jogador.
9. **Cache das engines (GXP-3):** cada ação monta uma `Duel::Session` com os dados do banco.
   A engine viva do duelo fica num cache LRU da instância (`Duel::EngineCache`, 32 duelos,
   uns 2 MB cada). A chave é o id do duelo mais um hash (SHA-256) das respostas: qualquer
   diferença com o banco (outra instância avançou o duelo, transação desfeita) faz o duelo
   ser refeito pelo replay, com o mesmo resultado. A engine sai do cache enquanto está em
   uso, então duas requisições nunca mexem nela ao mesmo tempo. Duelo que acabou não volta
   para o cache.
10. **Resposta recusada:** quando a engine recusa uma resposta (`MSG_RETRY`), o duelo fica
    na mesma pergunta, igualzinho (conferido em teste: o resto do duelo não muda). A
    resposta não entra no histórico e a `Duel::Session` avisa com `InvalidResponse`.
11. **Tag (GXP-4):** a engine tem times nativos. Os decks vão na **ordem dos turnos**:
    `[A, B]` no 1x1 e `[A1, B1, A2, B2]` no Tag (posições pares são do time 0, que começa).
    A engine troca o duelista do lado no começo de cada turno, menos no turno 1; por isso o
    primeiro a jogar pelo time 1 entra como duelista 1 (`Duel::Engine#duelist_index`). Campo,
    cemitério, banidas e PV são do lado (o PV inicial é o `starting_lp`: 8000, confirmado
    pelo Pedro); mão, deck e Extra Deck são de cada duelista. A mão inicial de quem não está
    na vez é comprada sem mensagem: o servidor sabe quais são (as 5 do topo do deck dele) e
    a `MSG_TAG_SWAP` mostra a mão na troca. Isso importa para a visão de cada jogador
    (decisão 7 do escopo: o parceiro vê a mão do companheiro).
12. **Destiny Draw (GXP-4; regra revista no GXP-20):** script de regra nosso,
    `app/services/duel/destiny_draw.lua` (baseado no `c511004000.lua` do Project Ignis),
    **ligado por padrão**; `destiny_draw: false` desliga, por duelo, nunca no meio. A regra é
    a do jogo de referência, que mantém o sistema do jogo anterior da série (Yugipedia:
    "Destiny Draw (rule)" e as páginas dos dois jogos):
    - o lado está em apuros com PV até 4000, o oponente controlando monstro e nenhum monstro
      do lado com ATK maior que o do monstro mais forte do oponente;
    - se a situação não virou até a segunda Fase de Compra, o duelista da vez pode usar: no
      lugar da compra normal, compra uma das cartas Destiny que marcou, sorteada. Aqui ela
      vai para o topo do deck no começo da Fase de Compra (`EVENT_PREDRAW`), antes da compra.
      Recusar não gasta: a pergunta volta enquanto a situação não virar;
    - uma vez por duelo para cada lado, inclusive no Tag. No Tag, as Fases de Compra contam
      por lado (o PV e o campo são da dupla).

    As fontes divergem num detalhe: a página da regra fala em PV "abaixo de 4000"; a do jogo
    anterior, em "4000 ou menos". Ficou "até 4000", que é a descrição específica do sistema.
    As cartas Destiny são os códigos que cada duelista marcou (`destiny:` no deck); no Tag, o
    duelista da vez sai da contagem de turnos do lado. A pergunta é um `SELECT_YESNO` com a
    descrição `aux.Stringid(511004000, 0)` (`Duel::Engine::DESTINY_DRAW_QUESTION`); a resposta
    fica no histórico e o sorteio usa o gerador da engine, então o replay sai igual
    (conferido em teste). Confirmado pelo Pedro em 07/11/2026: regra do jogo de referência,
    ligado por padrão e PV da dupla no Tag de 8000, configurável.

## Números do GXP-3 (07/11/2026)

O `/up/engine` refaz pela `Duel::Session` o duelo gravado dos bots (403 respostas, 20
turnos) em dois passos, que são as duas situações de uma ação no servidor:

- **ação fria:** o duelo não está no cache; refaz as 401 primeiras respostas do zero e
  aplica a 402ª;
- **ação quente:** a engine ficou no cache; aplica a última resposta, que termina o duelo
  (inclui liberar a engine, cerca de 1,3 ms). No meio do duelo, uma ação quente leva uns
  0,3 ms, quase tudo para calcular o hash das respostas.

Localmente (2 vCPU, modo produção, `bin/rails "duel:benchmark[200]"`):

| Tempo (ms) | 1ª chamada | p50 | p95 | máximo |
| --- | --- | --- | --- | --- |
| Ação fria | 81,4 | 22,6 | 32,7 | 81,4 |
| Ação quente | 2,3 | 1,5 | 2,4 | 3,1 |

A 1ª chamada do processo inclui ler do disco as cartas e os scripts do duelo (o catálogo é
lido sob demanda; ler tudo de uma vez custava cerca de 310 ms na Vercel).

Na Vercel (iad1), com o workflow *Medição da engine* (50 chamadas seguidas):

| Tempo (ms) | 1ª chamada | p50 | p95 | máximo |
| --- | --- | --- | --- | --- |
| Ação fria (duelo refeito do zero), no app | 26,3 | 31,5 | **42,3** | 54,3 |
| Ação quente (engine no cache), no app | 1,6 | 2,6 | 3,9 | 4,6 |
| Requisição inteira ao `/up/engine`, vista do GitHub | 105,1 | 110,6 | 156,9 | 183,6 |
| Só rede, Vercel e Rails (`/up`), vista do GitHub | 84,8 | 77,9 | 143,0 | 153,2 |

Antes do cache, o `/up/engine` refazia o duelo inteiro (403 respostas) do zero: p50 34,1 ms
e p95 46,1 ms no app. Na CI, num container recém-criado, a primeira chamada deu 46,9 ms
(fria) e 0,84 ms (quente).

Mesmo o pior caso (duelo fora do cache) fica bem abaixo da meta de 300 ms no p95: o plano
B (VM própria) não é necessário. A maior parte da requisição é rede, Vercel e Rails (o
`/up`, sem engine, já leva p50 78 ms visto do GitHub); a região das funções (hoje iad1) e a
do banco ficam para o ADR de hospedagem (GXP-8).

## Consequências

- A imagem do container cresce cerca de 52 MB (scripts 39 MB, `.cdb` 10 MB, biblioteca 3 MB).
  O GXP-7 reduz os scripts ao pool do jogo de referência.
- A CI e quem desenvolve precisam de g++, meson e ninja para compilar a engine (cerca de
  40 s; o `bin/setup` já chama o `bin/build-engine`).
- O `/up/engine` refaz em produção, pelo replay, um duelo inteiro gravado: prova que a
  biblioteca, os scripts e os dados das cartas estão na imagem e que o replay continua
  dando o mesmo resultado.

## Alternativas descartadas

- **Escrever as regras do zero:** inviável no tamanho do projeto.
- **`ygopro-core` original (Fluorohydride, MIT):** sem a coleção de scripts pré-errata e de
  anime do Project Ignis.
- **Engine num processo separado (servidor próprio):** precisaria de uma máquina sempre
  ligada; com FFI tudo roda no container da Vercel.
