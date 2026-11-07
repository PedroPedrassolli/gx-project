# ADR 0006: dados do jogo de referência

- **Data:** 07/11/2026
- **Situação:** aceita (GXP-6).

## Contexto

O escopo (Anexo B) pede, com fonte por item: as cartas do jogo, os pacotes (preço, cartas,
raridade, disponibilidade), as chances por raridade, o deck inicial, o conversor, os 104
desafios, a regra de nível e a banlist. Nada inventado: o que não for achado vai para o
Anexo C. A Yugipedia tem quase tudo isso em páginas estruturadas, sob CC BY-SA, e responde
pela API do MediaWiki.

## Decisão

1. **Um gerador versionado em vez de copiar à mão.** `bin/rails dados:jogo`
   (`lib/game_data`) lê as páginas pela API e grava os YAML de `db/seeds/jogo`. Ele pede de
   50 em 50 páginas, com 1 s de pausa, e se identifica no User-Agent. Rodar de novo atualiza
   tudo; as conferências saem no terminal.
2. **Páginas pelo id, fonte pela revisão.** O título das páginas tem o nome do jogo, que não
   entra no repositório (ADR 0003). O código guarda o id das páginas fixas e o da categoria
   dos pacotes, e cada dado guarda o número da revisão lida (`oldid`), que leva à versão
   exata da página.
3. **Identidade da carta: passcode.** A lista de um pacote cita a carta pelo nome que o jogo
   usava. O gerador procura a página da carta oficial (com redirecionamento do nome antigo
   para o atual) e usa o passcode dela. As cartas do anime que o jogo trouxe valem pela
   página do jogo, com o número interno dele e sem passcode, mesmo quando o OCG imprimiu
   depois uma carta com o mesmo nome e outro efeito: a lista delas vem da página do jogo.
4. **Pacote que junta outros guarda a regra, não a lista.** *Checkered Flag 1* (os 34
   primeiros pacotes, menos *Simple is Best*) e *Checkered Flag 2* (todos) ficam com
   `inclui`, e o importador da F1 monta a lista. O gerador confere a conta com o tamanho que
   a página informa.
5. **Disponibilidade escrita à mão** (`disponibilidade.yml`), porque a regra original vem em
   texto corrido e muda pouco. Online não há parceiro, história, minigame nem torneio:
   - regra com alternativa por nível, % ou desafios fica com a alternativa (o pacote do
     parceiro fica pelo nível que o próprio jogo dá como alternativa; os dois pacotes de UMD,
     por "todos os desafios");
   - entram dois tipos que o escopo não listava, porque o jogo usa: % de todas as cartas e
     "qualquer uma de várias regras";
   - o que não tem alternativa fica `pendente`, com a regra original resumida, para o Pedro
     decidir (Anexo C).
6. **Nome atual e nome do jogo.** `nome` é o nome atual da carta; `nome_no_jogo` guarda o
   antigo quando mudou (212 cartas).
7. **Licença dos dados:** os YAML seguem a CC BY-SA da Yugipedia, com crédito no README da
   pasta. O código continua AGPL.

## Consequências

- O pool tem 3.499 cartas; a página do jogo diz 3.501. As 2 que faltam e as 7 cartas do
  anime sem passcode nem número interno ficam para o GXP-7, que cruza o pool com os scripts
  e as imagens.
- Regra de nível e chances por raridade não estão na Yugipedia: valem a regra provisória e
  os pesos do admin que o escopo já prevê, e as duas perguntas vão para o Anexo C.
- O texto dos desafios fica em inglês, como na fonte. A versão em português e a regra que o
  `ChallengeEvaluator` confere entram na F4.

## Alternativas descartadas

- **Copiar as tabelas à mão:** 3.499 cartas e 48 pacotes, sem como refazer depois.
- **Achar o passcode pelo nome no BabelCDB:** 198 nomes do jogo não batem com o nome atual,
  e as cartas do anime têm o mesmo nome da impressão posterior.
- **Interpretar o texto da disponibilidade no código:** muitos formatos de frase para 48
  pacotes; à mão, cada regra fica clara e revisada.
