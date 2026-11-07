# ADR 0001: engine de duelo

- **Data:** 06/11/2026
- **Situação:** aceita (GXP-2). Os números da Vercel entram no GXP-3.

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

## Consequências

- A imagem do container cresce cerca de 52 MB (scripts 39 MB, `.cdb` 10 MB, biblioteca 3 MB).
  O GXP-7 reduz os scripts ao pool do jogo de referência.
- A CI e quem desenvolve precisam de g++, meson e ninja para compilar a engine (cerca de
  40 s; o `bin/setup` já chama o `bin/build-engine`).
- O `/up/engine` roda um duelo curto em produção: prova que a biblioteca, os scripts e os
  dados das cartas estão na imagem.

## Alternativas descartadas

- **Escrever as regras do zero:** inviável no tamanho do projeto.
- **`ygopro-core` original (Fluorohydride, MIT):** sem a coleção de scripts pré-errata e de
  anime do Project Ignis.
- **Engine num processo separado (servidor próprio):** precisaria de uma máquina sempre
  ligada; com FFI tudo roda no container da Vercel.
