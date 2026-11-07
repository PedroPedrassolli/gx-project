# Dados do jogo de referência

Cartas, pacotes, deck inicial, conversor, desafios e banlist do jogo de referência, tirados da
Yugipedia em 07/11/2026 pelo `bin/rails dados:jogo`. Só o `disponibilidade.yml` é escrito à
mão. As decisões estão no [ADR 0006](../../../../docs/adr/0006-dados-do-jogo.md).

| Arquivo | O que tem | Anexo B |
| --- | --- | --- |
| `cartas.yml` | 3.499 cartas: nome atual, nome no jogo (quando mudou depois), passcode ou o número interno do jogo (versões do anime), o passcode da impressão posterior das cartas do anime e a fonte | 1 |
| `pacotes.yml` | 48 pacotes na ordem da loja: preço em DP, cartas por pacote, tamanho e cada carta com a raridade | 2 |
| `disponibilidade.yml` | como cada pacote fica disponível (escrito à mão) | 2 |
| `deck_inicial.yml` | deck principal, side e as 3 cartas marcadas como Destiny | 4 |
| `conversor.yml` | grupos de 10 a 99 cartas | 5 |
| `desafios.yml` | os 104 desafios, com o texto original em inglês | 6 |
| `banlist.yml` | banlist padrão do jogo | 8 |
| `extras.yml` | cartas que saem por DLC e num minigame | 1 |
| `cobertura.yml` | o pool cruzado com a engine e as imagens: as exceções à regra geral, com a decisão de cada carta (gerado por `bin/rails dados:cobertura`) | GXP-7 |

Os itens 9 (Destiny Draw) e 10 (PV do Tag) estão no ADR 0001.

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

- **3.499 cartas**; a página do jogo diz 3.501. As 2 que faltam não estão em nenhuma das
  listas lidas.
- *Checkered Flag 2*: 3.477 cartas pela regra, igual à página. *Checkered Flag 1*: 2.268 pela
  regra; a página diz 2.267.
- 77 cartas são versões do jogo (cartas do anime): têm o número interno do jogo e não têm
  passcode. 7 cartas do anime não têm nenhum dos dois.
- 212 cartas mudaram de nome depois do jogo (`nome_no_jogo`).
- O conversor cita "That Which Feeds On Life", que a Yugipedia não acha com esse nome: no
  `conversor.yml` sai só o nome.

## Cobertura na engine e nas imagens (`cobertura.yml`)

Regra geral: a carta entra na engine pelo próprio passcode, com o script oficial (carta Normal
não tem script) e a imagem do YGOPRODeck. Em 07/11/2026:

- 3.415 cartas oficiais: todas têm dados no BabelCDB e imagem; 617 são Normais; 52 usam o
  script antigo (pré-errata), porque o jogo é de 2008.
- 84 cartas do anime: 61 usam o script não oficial da versão de video game (ou do anime);
  8 não têm script e usam a carta que o OCG imprimiu depois (`passcode_oficial` no
  `cartas.yml`); **15 ficam fora do pool** até alguém escrever o script.
- As cartas do anime não têm imagem no YGOPRODeck: mostram só o texto (escopo, 3.2).

## O que não veio da fonte (respostas do Pedro ao Anexo C, 07/11/2026)

- **Regra de subida de nível** (item 7): a Yugipedia não traz. Ficou uma regra inspirada
  no jogo: 1 nível a cada 1.000 DP ganhos (escopo, 3.5).
- **Chances por raridade** (item 3): a Yugipedia não traz. Ficaram os pesos 75, 18, 5 e 2
  (escopo, 3.4).
- **8 pacotes** que no jogo dependem de minigame, torneio ou história e as **18 cartas**
  que não saem em pacote (`extras.yml`): saem por missões
  (`backend/db/seeds/missoes.yml`).
