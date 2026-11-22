# ADR 0015: front novo, direção Holo

- **Data:** 22/11/2026
- **Situação:** aceita (GXP-126, GXP-127 e GXP-128).

## Contexto

O Pedro pediu para refazer o front antes do social e do acabamento: intuitivo, moderno, bonito
e gostoso de usar, no computador e no celular, sem perder segurança nem velocidade. A auditoria
de 22/11/2026 passou por todas as telas, nos dois tamanhos e com dados de teste:

- **Navegação.** No celular, a marca, a conta, o menu e o aviso do duelo ocupavam um quinto da
  tela antes do conteúdo. "Sair" ficava no menu principal; Personagens e Desafios, fora dele.
- **Início.** Seis atalhos grandes e iguais, dois ou três por tela; nada dizia o que fazer agora
  (voltar ao duelo, o próximo personagem, o pacote novo).
- **Títulos.** Todo título de página tinha uns 60 px e muito espaço em volta: no celular, o
  conteúdo começava perto da metade da tela. Nome de carta em versaletes quebrava em três linhas.
- **Cartas.** A imagem, o que o jogo tem de mais bonito, aparecia pequena: o catálogo e o baú
  mostram uma miniatura e muito texto; no celular, uma carta por linha.
- **Deck Edit.** O deck é uma lista de 40 linhas de texto (uns 3.600 px); no celular, o baú
  fica embaixo dela. Não dá para ver o deck de uma vez.
- **Loja.** Os pacotes são cartões só de texto, todos iguais; o progresso para liberar aparece
  como porcentagem no meio da frase.
- **Mesa de duelo.** No computador, a mesa é uma coluna estreita no meio (zonas de 60 px e
  cartas ilegíveis), com o painel da carta vazio quase sempre. Os PV são pequenos, e as fases
  são seis pílulas de 22 px no meio do campo, disputando lugar com os botões.

A pesquisa seguiu as heurísticas de Nielsen, as Leis de UX (Fitts, Hick e Jakob), a WCAG 2.2
e os jogos de Yu-Gi-Oh! que os jogadores já conhecem: Master Duel (a mesa vista de cima, o
detalhe da carta à esquerda, o histórico que abre e fecha), Duel Links (retrato no celular, mão
grande, campo simples) e os Tag Force.

## Decisão

1. **Direção Holo**, escolhida pelo Pedro entre três (Academia, clara; Holo, escura; Arena,
   azul): a interface fica quieta e as cartas brilham. O efeito holográfico só aparece no que é
   raro ou importante: a carta rara, o botão principal e os seus PV.
2. **Tokens** em `styles.css`: fundo `#0A0D16`, superfícies `#141A29` e `#1C2337`, texto
   `#EEF1F8`, texto secundário `#97A0BA`, destaque ciano `#9EE6FF` e o gradiente holográfico
   (`#6BE7FF`, `#A98BFF`, `#FF8AD6` e `#FFD27A`). Títulos, números e botões em Oxanium; texto em
   Hanken Grotesk (as duas OFL, servidas por nós pelo Fontsource). Cantos de 12 a 14 px.
3. **Navegação.** No celular e no tablet (até 64rem), abas embaixo, perto do polegar: Início,
   Jogar, Decks, Coleção e Loja (sem conta: Início, Cartas, Entrar e Criar conta). No
   computador, os mesmos itens no topo. O saldo de DP e o nível ficam no topo; "Sair" foi para a
   página da conta. "Jogar" junta os personagens e as salas; a coleção inclui o catálogo.
4. **Cada tela, um PR**, nesta ordem: início (a próxima ação primeiro), coleção e catálogo (grade
   de cartas, filtros numa gaveta), Deck Edit (o deck em grade de cartas), loja (capas e a
   abertura carta a carta), jogar (personagens e salas), mesa de duelo (zonas maiores, PV
   grandes, a carta escolhida à esquerda e as fases numa coluna no computador) e o resto.
5. **Movimento com propósito:** de 150 a 250 ms nas respostas ao toque, o brilho só nas raras e
   nada que se mexa sozinho com "reduzir movimento" ligado.
6. **WCAG 2.2 AA:** alvo de toque de 44 px nos botões principais (24 px no mínimo), foco visível
   e nunca escondido pela barra de abas, alternativa a arrastar e contraste de 4,5:1 no texto.
7. **Segurança e desempenho como antes:** a CSP continua sem estilo inline no HTML (valor
   dinâmico entra por variável CSS, pelo CSSOM), nenhuma biblioteca de interface nova, as
   imagens continuam no Cloudflare Pages e o desenho continua nosso: nada de logo, verso de
   carta ou tela oficial.

## Consequências

- Enquanto uma área não é refeita, ela já usa as cores e as fontes novas, mas mantém o desenho
  antigo.
- Os testes de ponta a ponta mudam junto com cada tela; o de layout confere também 1024 px, a
  largura em que o menu passa para o topo.
- No Deck Edit (GXP-132), o detalhe da carta abre por cima em qualquer largura, com "Pôr no
  deck", "Tirar uma cópia" e o Destiny no rodapé, que fica à vista: dá para ler a carta e
  decidir sem fechar. No celular, Deck e Baú viram abas e a barra com o Salvar fica presa no
  topo; no computador, o baú é uma coluna parada ao lado do deck.
- As fontes antigas (Spectral) saíram; as novas são variáveis, um arquivo para todos os pesos
  (uns 50 KB no total, contra uns 60 KB de antes).
