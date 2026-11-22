# ADR 0014: textos das cartas em português

- **Data:** 21/11/2026
- **Situação:** aceita (GXP-106).

## Contexto

O Pedro pediu todas as descrições das cartas em português. Das cartas do pool, 1.009 não
tinham um texto em português que pudesse aparecer: 954 nunca saíram em português, 47 mostram o
texto da época (pré-errata), que não tem tradução oficial, e 8 vieram da fonte com o português
oficial quebrado (frases sem sentido).

## Decisão

1. **Traduzimos nós mesmos os 1.009 textos**, com os termos das traduções oficiais (Cemitério,
   Invocação-Especial, Baixar, banir, PV, VIRE...). Nome de carta entre aspas usa o nome em
   português quando a carta tem um, o mesmo que a tela mostra; nome de arquétipo usa o dos
   textos oficiais ("HERÓI do Elemento", "Besta Gladiadora"); o resto fica em inglês.
2. **As traduções ficam em `db/seeds/jogo/traducoes.yml`**, escrito à mão, junto com o inglês
   que foi traduzido. A importação só usa a tradução quando esse inglês é o mesmo da carta: se o
   `dados:jogo` trouxer um texto novo, a carta volta a mostrar o inglês e o teste dos dados
   aponta qual tradução refazer.
3. **O português oficial continua valendo onde existe.** A exceção são os 8 quebrados, marcados
   com `substitui: true`.
4. **A tela avisa quando o português é nosso.** A carta guarda isso (`text_pt_unofficial`) e o
   catálogo e o duelo mostram "Tradução não oficial, feita pelo GX Project."

## Consequências

- Toda carta do pool aparece em português; o teste dos dados garante.
- As traduções derivam dos textos da Yugipedia: seguem a CC BY-SA, como o resto da pasta.
- Uma tradução nossa pode errar um detalhe de regra. O texto em inglês continua a um toque, na
  troca de idioma do catálogo.
