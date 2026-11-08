# Dados do jogo de referência

Cartas, pacotes, deck inicial, conversor, desafios e banlist do jogo de referência, tirados da
Yugipedia em 07/11/2026 pelo `bin/rails dados:jogo`. Só o `disponibilidade.yml` é escrito à
mão. As decisões estão no [ADR 0006](../../../../docs/adr/0006-dados-do-jogo.md).

| Arquivo | O que tem | Anexo B |
| --- | --- | --- |
| `cartas.yml` | 3.496 cartas: nome atual, nome no jogo (quando mudou depois), passcode ou o número interno do jogo (versões do anime), o passcode da impressão posterior das cartas do anime, tipo, atributo, raça, nível, ATK, DEF, o texto em inglês e, quando a carta saiu em português, nome e texto em português, e a fonte | 1 |
| `pacotes.yml` | 48 pacotes na ordem da loja: preço em DP, cartas por pacote, tamanho e cada carta com a raridade | 2 |
| `disponibilidade.yml` | como cada pacote fica disponível (escrito à mão) | 2 |
| `deck_inicial.yml` | deck principal, side e as 3 cartas marcadas como Destiny | 4 |
| `conversor.yml` | grupos de 10 a 99 cartas | 5 |
| `desafios.yml` | os 104 desafios, com o texto original em inglês | 6 |
| `banlist.yml` | banlist padrão do jogo | 8 |
| `extras.yml` | cartas que saem por DLC e num minigame | 1 |
| `cobertura.yml` | o pool cruzado com a engine e as imagens: as exceções à regra geral, com a decisão de cada carta (gerado por `bin/rails dados:cobertura`) | GXP-7 |

Os itens 9 (Destiny Draw) e 10 (PV do Tag) estão no ADR 0001.

Para gravar o catálogo no banco: `bin/rails catalogo:importar`. Ele usa o código da engine
do `cobertura.yml`, deixa de fora as cartas que saíram do pool e monta a lista dos pacotes
que juntam outros. Pode rodar quantas vezes quiser. Mudou o pool? Rode também o workflow
*Imagens das cartas*: ele baixa do YGOPRODeck só as imagens que ainda não estão no ar.

## Fonte e licença

- Cada `fonte` é o número da revisão da página lida na Yugipedia:
  `https://yugipedia.com/index.php?oldid=N`. O título das páginas tem o nome do jogo, que não
  entra no repositório (ADR 0003); o número leva à página exata.
- As listas e os textos vêm da Yugipedia, sob
  [CC BY-SA](https://yugipedia.com/wiki/Yugipedia:Licensing), reorganizados por nós. Crédito:
  colaboradores da Yugipedia. **Estes arquivos seguem a CC BY-SA, não a AGPL do código.**
- Para atualizar, rode `bin/rails dados:jogo` (uns 3 minutos: pede de 50 em 50 páginas, com
  pausa entre os pedidos). Ele regrava os arquivos gerados e mostra as conferências abaixo.

## Conferências (07/11/2026)

- **3.496 cartas**; a página do jogo diz 3.501. As 5 que faltam não estão em nenhuma das
  listas lidas.
- *Checkered Flag 2*: 3.477 cartas pela regra, igual à página. *Checkered Flag 1*: 2.268 pela
  regra; a página diz 2.267.
- 78 cartas são do anime: 77 têm o número interno do jogo e não têm passcode; 1 não tem
  nenhum dos dois.
- 213 cartas mudaram de nome depois do jogo (`nome_no_jogo`).
- 2.221 monstros, 723 magias e 552 armadilhas, todos com texto em inglês; 2.574 têm nome e
  2.521 têm texto em português. 24 monstros têm ATK "?" e 17 têm DEF "?" (ficam sem valor).
- Título do jogo sem página própria cai na página do nome puro, que às vezes é de um pacote,
  arquétipo ou episódio. Só vale página com a caixa de uma carta: o gerador tenta
  `Nome (card)`, depois a página que o aviso do topo indica e, por último, uma carta com o
  mesmo nome em outra caixa de letras ("Feeds On Life" e "Feeds on Life").

## Cobertura na engine e nas imagens (`cobertura.yml`)

Regra geral: a carta entra na engine pelo próprio passcode, com o script oficial (carta Normal
não tem script) e a imagem do YGOPRODeck. Em 07/11/2026:

- 3.418 cartas oficiais: todas têm dados no BabelCDB e imagem; 617 são Normais; 48 usam o
  script antigo (pré-errata), porque o jogo é de 2008, e mostram o texto da época (`texto` e
  `fonte_texto` no `cobertura.yml`). Outras 4 têm script pré-errata, mas ele não segue a
  versão de 2008 em inglês, que joga como a de hoje: *Toon World*, *Dragon Seeker*,
  *Amazoness Fighter* e *Blue-Eyes Ultimate Dragon* usam o script oficial.
- 78 cartas do anime: 61 usam o script não oficial da versão de video game (ou do anime);
  5 não têm script e usam a carta que o OCG imprimiu depois (`passcode_oficial` no
  `cartas.yml`), e o jogador vê os dados dela (`impressao`); **12 ficam fora do pool** até
  alguém escrever o script.
- As cartas do anime não têm imagem no YGOPRODeck: mostram só o texto (escopo, 3.2). As 5
  que usam a carta impressa depois mostram a imagem dela.

## O que não veio da fonte (respostas do Pedro ao Anexo C, 07/11/2026)

- **Regra de subida de nível** (item 7): a Yugipedia não traz. Ficou uma regra inspirada
  no jogo: 1 nível a cada 1.000 DP ganhos (escopo, 3.5).
- **Chances por raridade** (item 3): a Yugipedia não traz. Ficaram os pesos 75, 18, 5 e 2
  (escopo, 3.4).
- **8 pacotes** que no jogo dependem de minigame, torneio ou história e as **18 cartas**
  que não saem em pacote (`extras.yml`): saem por missões
  (`backend/db/seeds/missoes.yml`).
