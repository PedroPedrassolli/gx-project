# ADR 0006: dados do jogo de referência

- **Data:** 07/11/2026
- **Situação:** aceita (GXP-6, GXP-7 e GXP-25).

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

8. **Cobertura na engine (GXP-7).** `bin/rails dados:cobertura` cruza o pool com os scripts
   e o BabelCDB da engine e com a lista de imagens do YGOPRODeck, e grava só as exceções em
   `cobertura.yml`, cada uma com o código que a engine usa:
   - carta oficial com script pré-errata usa a versão antiga (o jogo é de 2008, e o escopo
     fixa "MR1 + pré-errata"), menos quando a revisão de 07/11/2026 achou que o script segue
     outra versão e a de 2008 em inglês joga como a de hoje: *Toon World* e *Dragon Seeker*
     (versões que nunca saíram em inglês), *Amazoness Fighter* (ATK 1300 da primeira
     impressão; em 2008 já era 1500) e *Blue-Eyes Ultimate Dragon* (DEF 3000 do *Gold
     Series*, que o *Retro Pack* de julho de 2008 voltou para 3800). Essas usam o oficial;
   - carta do anime usa o script não oficial, nesta ordem: versão de video game (`(VG)`),
     mesmo nome, versão do anime (`(Anime)`);
   - carta do anime sem script usa a carta que o OCG imprimiu depois, se houver (o efeito
     pode diferir, mas a carta fica jogável);
   - sem nada disso, a carta sai do pool até alguém escrever o script. Tudo isso é
     reversível: é só dado.
9. **O que o jogador vê (GXP-25).** Tipo, propriedade, atributo, raça, os outros tipos do
   monstro, nível, ATK, DEF e o texto saem da caixa da página da carta, sem a marcação da
   wiki. O texto fica em inglês e, quando a carta saiu em português, também em português; a
   tela escolhe pela configuração do jogador. O BabelCDB não entra aqui: ele não tem licença
   (ADR 0001). Os valores ficam como a página escreve (`Monster`, `DARK`, `Fiend`) e a tela
   traduz. **O que a tela mostra segue o script que a engine roda:**
   - carta pré-errata mostra o texto da época: a versão da página `Card Errata:` que valia
     quando o jogo saiu (28/11/2008, a primeira data em inglês da página do jogo). Cada versão
     vale desde o primeiro pacote em inglês que a imprimiu; sem nenhuma antes do jogo, vale a
     impressão original. Esse texto fica só em inglês, porque o português da página é o atual;
   - carta do anime que usa a carta impressa depois mostra os dados da impressão
     (`impressao` no `cartas.yml`), com o nome que o jogo usava.

   O texto pré-errata que o BabelCDB traz não serve: não tem licença e é reescrito no
   formato de hoje. Comparar com ele para escolher a versão errou em casos como *Darkness
   Approaches*, por isso a escolha é pela data.

## Consequências

- O pool tem 3.496 cartas; a página do jogo diz 3.501. Das 78 cartas do anime, 61 têm
  script, 5 usam a impressão posterior e 12 saem do pool (lista no `cobertura.yml`, para o
  Pedro revisar quando quiser).
- Regra de nível e chances por raridade não estão na Yugipedia: valem a regra provisória e
  os pesos do admin que o escopo já prevê, e as duas perguntas vão para o Anexo C.
- O texto dos desafios fica em inglês, como na fonte. A versão em português e a regra que o
  `ChallengeEvaluator` confere entram na F4.

## Alternativas descartadas

- **Copiar as tabelas à mão:** 3.496 cartas e 48 pacotes, sem como refazer depois.
- **Achar o passcode pelo nome no BabelCDB:** 198 nomes do jogo não batem com o nome atual,
  e as cartas do anime têm o mesmo nome da impressão posterior.
- **Interpretar o texto da disponibilidade no código:** muitos formatos de frase para 48
  pacotes; à mão, cada regra fica clara e revisada.
