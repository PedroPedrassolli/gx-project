import { useEffect } from "react";

// Vira true quando a pessoa navega dentro do site (o Layout avisa). Na primeira página
// aberta, o foco fica onde o navegador põe.
let navigated = false;

export function markNavigation() {
  navigated = true;
}

// "Coleção · GX Project": cada aba diz em que página a pessoa está (WCAG 2.4.2).
export function pageTitle(title?: string) {
  return title ? `${title} · GX Project` : "GX Project";
}

// Título da aba e, depois de uma navegação, o foco no título da página nova: quem usa
// teclado ou leitor de tela começa pelo conteúdo, e não pelo link que clicou.
export function usePageTitle(title?: string) {
  useEffect(() => {
    document.title = pageTitle(title);
    if (!navigated) return;

    const heading = document.querySelector<HTMLElement>("main h1");
    if (heading) {
      heading.tabIndex = -1;
      heading.focus();
    }
  }, [title]);
}
