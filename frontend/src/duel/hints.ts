import type { Prompt } from "./api.ts";

// Os textos do próprio jogo para a dica do que escolher (HINTMSG_* do constant.lua).
const HINTS: Record<number, string> = {
  500: "Escolha a carta para oferecer como Tributo",
  501: "Escolha a carta para descartar",
  502: "Escolha a carta para destruir",
  503: "Escolha a carta para banir",
  504: "Escolha a carta para enviar ao Cemitério",
  505: "Escolha a carta para devolver à mão",
  506: "Escolha a carta para adicionar à mão",
  507: "Escolha a carta para devolver ao Deck",
  508: "Escolha o monstro para invocar",
  509: "Escolha o monstro para a Invocação-Especial",
  510: "Escolha a carta para baixar",
  511: "Escolha as Matérias de Fusão",
  512: "Escolha as Matérias de Sincro",
  513: "Escolha as Matérias Xyz",
  514: "Escolha uma carta com a face para cima",
  515: "Escolha uma carta com a face para baixo",
  516: "Escolha um monstro em Posição de Ataque",
  517: "Escolha um monstro em Posição de Defesa",
  518: "Escolha a carta para equipar",
  519: "Escolha a Matéria Xyz para desanexar",
  520: "Escolha o monstro para assumir o controle",
  521: "Escolha a carta para destruir no lugar",
  522: "Escolha um monstro com a face para cima em Ataque",
  523: "Escolha um monstro com a face para cima em Defesa",
  524: "Escolha um monstro com a face para baixo em Ataque",
  525: "Escolha um monstro com a face para baixo em Defesa",
  526: "Escolha a carta para revelar ao oponente",
  527: "Escolha a carta para colocar no campo",
  528: "Escolha o monstro para mudar de posição",
  529: "Escolha uma carta sua",
  530: "Escolha uma carta do oponente",
  531: "Escolha os monstros para o Tributo da invocação",
  532: "Escolha o monstro de onde desanexar a Matéria",
  533: "Escolha as Matérias de Link",
  549: "Escolha o alvo do ataque",
  550: "Escolha o efeito para ativar",
  551: "Escolha o alvo do efeito",
  552: "Escolha cara ou coroa",
  553: "Escolha o resultado do dado",
  554: "Escolha um tipo de carta",
  555: "Escolha uma opção",
  556: "Escolha o efeito para ativar ou resolver",
  560: "Escolha",
  561: "Escolha a posição",
  562: "Declare um Atributo",
  563: "Declare um Tipo",
  564: "Declare o nome de uma carta",
  565: "Declare um número",
  566: "Escolha o efeito para ativar",
  567: "Declare um Nível",
  568: "Escolha a carta para resolver o efeito",
  569: "Escolha a zona",
  570: "Escolha a zona que vai ficar inutilizável",
  571: "Escolha a zona para onde mover",
  572: "Escolha a carta para colocar o marcador",
  575: "Escolha a carta para negar",
  577: "Escolha a carta para aplicar o efeito",
  578: "Escolha a carta para anexar",
  579: "Escolha a carta para voltar ao Cemitério",
};

// A dica da pergunta: o texto da carta (vem do servidor, em inglês) ou o texto do jogo.
export const hintText = (prompt: Prompt) =>
  (prompt.hint_text as string | null | undefined) ?? HINTS[Number(prompt.hint)];

// Os textos do próprio jogo (strings.conf da engine) que a engine e os scripts do pool usam
// nas perguntas de sim ou não e nas opções. Sem eles a tela mostrava "Confirmar?" ou "Opção
// 1", e quem jogava não sabia o que estava aceitando. "%ls" é o nome da carta; o segundo,
// onde ela está.
const SYSTEM: Record<number, string> = {
  30: "Houve um replay. Continuar o ataque?",
  31: "Atacar diretamente?",
  32: "Fazer outra Fase de Batalha?",
  65: "Usar o efeito",
  70: "Cartas de Monstro",
  71: "Cartas de Magia",
  72: "Cartas de Armadilha",
  90: "Fazer a Invocação-Normal sem Tributo?",
  91: "Usar a Invocação-Normal a mais?",
  92: "Usar um monstro do oponente?",
  93: "Continuar escolhendo as Matérias?",
  94: "Ativar o efeito desta carta agora?",
  95: "Usar o efeito de “%ls”?",
  96: "Usar o efeito de “%ls” para não ser destruída?",
  97: "Colocar “%ls” na Zona de Magias e Armadilhas?",
  98: "Usar um efeito no lugar do custo?",
  200: "Usar o efeito de “%ls” (%ls)?",
  210: "Continuar escolhendo cartas?",
  221: "Ativar o efeito de gatilho de “%ls” (%ls)?",
  222: "Ativar um efeito de gatilho?",
  573: "Adicionar à mão",
  1068: "Equipar",
  1150: "Ativar",
  1151: "Invocação-Normal",
  1152: "Invocação-Especial",
  1153: "Baixar",
  1213: "Sim",
  1214: "Não",
};

// Texto do jogo de uma descrição sem carta (o número do texto, abaixo de 2^20), com o nome
// e o lugar da carta no lugar do "%ls". As descrições de carta vêm prontas do servidor.
export function systemText(description: unknown, name = "esta carta", place?: string) {
  const text = SYSTEM[Number(description)];
  if (!text) return undefined;
  const filled = text.replace("%ls", name);
  return place ? filled.replace("%ls", place) : filled.replace(" (%ls)", "");
}
