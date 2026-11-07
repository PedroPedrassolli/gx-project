# ADR 0001: engine de duelo

- **Data:** 06/11/2026
- **Situação:** aceita (GXP-2). Cache e números da Vercel no GXP-3 (07/11/2026).

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

## Números do spike (06/11/2026, local, 2 vCPU)

Dois bots simples jogaram 10 duelos completos com sementes diferentes:

| Medida | Resultado |
| --- | --- |
| Duelos | 10, todos até o fim, todos determinísticos |
| Tamanho | 212 a 493 respostas, 6 a 21 turnos |
| Respostas automáticas (cadeia sem opção) | 2.549 de 3.494 (73,0%) |
| Reconstruir do zero até um ponto do duelo (646 amostras) | p50 16,7 ms · **p95 20,4 ms** · máx. 30,9 ms |
| Só começar o duelo (criar, scripts base, 80 cartas) | p50 14,5 ms · p95 15,2 ms |
| Aplicar uma resposta com o duelo em memória | p95 abaixo de 0,1 ms |
| Memória por duelo em memória | 1,8 MB |
| Erros de script | 0 |

Com 3.000 respostas (bem acima de um duelo real), reconstruir do zero levou 89 ms. A meta
do escopo é p95 < 300 ms: sobra margem mesmo sem cache.

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

Na Vercel (iad1), antes do cache, com o workflow *Medição da engine* (50 chamadas
seguidas, cada uma refazendo o duelo inteiro do zero):

| Tempo (ms) | 1ª chamada | p50 | p95 | máximo |
| --- | --- | --- | --- | --- |
| Duelo inteiro refeito do zero, no app | 28,2 | 34,1 | 46,1 | 54,1 |
| Requisição inteira, vista do GitHub | 245,1 | 160,7 | 251,1 | 252,7 |

Mesmo o pior caso (duelo fora do cache) fica bem abaixo da meta de 300 ms no p95: o plano
B (VM própria) não é necessário. A maior parte da requisição é rede; a região das funções
(hoje iad1) e a do banco ficam para o ADR de hospedagem (GXP-8).

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
