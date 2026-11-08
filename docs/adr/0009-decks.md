# ADR 0009: Decks na API

- **Data:** 08/11/2026
- **Situação:** aceita (GXP-34).

## Contexto

O escopo pede vários decks por conta, validação ao vivo no front e definitiva no backend,
e importar e exportar em texto e no formato `.ydk` (3.3 e 5.6). Não diz se um deck
inválido pode ser salvo, nem como é o formato de texto, nem como a Destiny viaja.

## Decisão

1. **Deck inválido pode ser salvo, como rascunho.** Montar um deck leva tempo, e o
   jogador sai e volta. Toda resposta com um deck traz `errors` (as mensagens do
   `Decks::Validator`) e `valid`. Quem barra é quem usa: sala e fila (F3 e F5) só aceitam
   deck válido. O que a tabela não aceita continua barrado ao salvar: seção que não existe,
   menos de 1 ou mais de 3 cópias numa linha e carta fora do pool.
2. **Linhas:** uma por carta e seção, com a quantidade e a marca de Destiny. Salvar troca
   todas as linhas do deck de uma vez. Carta repetida na mesma seção do pedido é somada.
3. **`.ydk`** (YGOPro e EDOPro): um código por cópia, nas seções `#main`, `#extra` e
   `!side`. Exporta o passcode; carta do anime, que não tem passcode, vai com o código do
   script da engine. O formato não tem Destiny: exportar perde a marca, importar vem sem.
4. **Texto** (nosso): título da seção (`Main Deck`, `Extra Deck`, `Side Deck`), depois uma
   linha por carta, `3 Dark Magician`, com ` (Destiny)` no fim quando for o caso. Ao
   importar, aceita `3x`, título sem "Deck", nome em inglês ou em português, sem diferenciar
   maiúsculas. Linha que não deu para ler vira aviso com o número da linha.
5. **Importar não falha por pouco.** Carta fora do pool fica de fora e mais de 3 cópias
   viram 3, com um aviso para cada coisa; o deck é criado com o resto (deck de outro jogo
   costuma ter cartas que não existem aqui).
6. **Rotas:** `GET /api/decks` (lista), `GET /api/decks/:id`, `POST /api/decks`,
   `PATCH /api/decks/:id`, `DELETE /api/decks/:id`, `POST /api/decks/validate` (valida sem
   salvar), `POST /api/decks/import` (cria a partir do arquivo) e
   `GET /api/decks/:id/export?format=ydk|text` (baixa o arquivo). Só o dono vê e mexe.

## Consequências

- O front mostra os erros ao vivo com a mesma regra e pode salvar a qualquer momento.
- Validar um deck custa 4 consultas (linhas, cartas, banlist e coleção), feitas a cada
  leitura: decks são poucos por conta.
