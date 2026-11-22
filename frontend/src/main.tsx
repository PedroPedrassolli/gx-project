import { lazy, StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { BrowserRouter, Route, Routes } from "react-router";
import { App } from "./App.tsx";
import { Layout, NotFound } from "./Layout.tsx";
import { restoreStoredCatalog } from "./catalog/data.ts";
// Fontes do tema Holo (ADR 0015), servidas pelo próprio site (a CSP só aceita fontes daqui):
// Hanken Grotesk no texto e Oxanium nos títulos, números e botões. As duas são variáveis (um
// arquivo para todos os pesos) e o navegador só baixa o alfabeto latino, que cobre o português.
import "@fontsource-variable/hanken-grotesk/wght.css";
import "@fontsource-variable/oxanium/index.css";
import "./styles.css";

// Cada página vira um arquivo JS baixado só quando a pessoa abre: a página inicial não
// carrega o código do catálogo nem do Deck Edit. O Layout mostra "Carregando…" enquanto isso.
const Catalog = lazy(() => import("./catalog/Catalog.tsx").then((m) => ({ default: m.Catalog })));
const PlayPage = lazy(() => import("./play/PlayPage.tsx").then((m) => ({ default: m.PlayPage })));
const CollectionPage = lazy(() =>
  import("./collection/CollectionPage.tsx").then((m) => ({ default: m.CollectionPage })),
);
const ChallengesPage = lazy(() =>
  import("./challenges/ChallengesPage.tsx").then((m) => ({ default: m.ChallengesPage })),
);
const CharactersPage = lazy(() =>
  import("./characters/CharactersPage.tsx").then((m) => ({ default: m.CharactersPage })),
);
const ShopPage = lazy(() => import("./shop/ShopPage.tsx").then((m) => ({ default: m.ShopPage })));
const ConverterPage = lazy(() =>
  import("./shop/ConverterPage.tsx").then((m) => ({ default: m.ConverterPage })),
);
const DecksPage = lazy(() =>
  import("./decks/DecksPage.tsx").then((m) => ({ default: m.DecksPage })),
);
const DeckEditPage = lazy(() =>
  import("./decks/DeckEditPage.tsx").then((m) => ({ default: m.DeckEditPage })),
);
const LogInPage = lazy(() =>
  import("./account/LogInPage.tsx").then((m) => ({ default: m.LogInPage })),
);
const SignUpPage = lazy(() =>
  import("./account/SignUpPage.tsx").then((m) => ({ default: m.SignUpPage })),
);
const AccountPage = lazy(() =>
  import("./account/AccountPage.tsx").then((m) => ({ default: m.AccountPage })),
);
const ForgotPasswordPage = lazy(() =>
  import("./account/PasswordPages.tsx").then((m) => ({ default: m.ForgotPasswordPage })),
);
const NewPasswordPage = lazy(() =>
  import("./account/PasswordPages.tsx").then((m) => ({ default: m.NewPasswordPage })),
);
const VerifyEmailPage = lazy(() =>
  import("./account/VerifyEmailPage.tsx").then((m) => ({ default: m.VerifyEmailPage })),
);
const RoomsPage = lazy(() =>
  import("./rooms/RoomsPage.tsx").then((m) => ({ default: m.RoomsPage })),
);
const RoomPage = lazy(() => import("./rooms/RoomPage.tsx").then((m) => ({ default: m.RoomPage })));
const DuelPage = lazy(() => import("./duel/DuelPage.tsx").then((m) => ({ default: m.DuelPage })));
const ReplayPage = lazy(() =>
  import("./duel/ReplayPage.tsx").then((m) => ({ default: m.ReplayPage })),
);
const TermsPage = lazy(() =>
  import("./legal/LegalPages.tsx").then((m) => ({ default: m.TermsPage })),
);
const PrivacyPage = lazy(() =>
  import("./legal/LegalPages.tsx").then((m) => ({ default: m.PrivacyPage })),
);

// Dados da API pelo TanStack Query; as páginas pelo React Router (escopo 5.8). A Vercel
// manda qualquer caminho para o index.html.
const queryClient = new QueryClient({
  defaultOptions: { queries: { retry: 1, refetchOnWindowFocus: false } },
});
// O catálogo e os textos guardados da última visita aparecem já, sem esperar o servidor.
void restoreStoredCatalog(queryClient);

const root = document.getElementById("root");
if (!root) throw new Error("elemento #root não encontrado no index.html");

createRoot(root).render(
  <StrictMode>
    <QueryClientProvider client={queryClient}>
      <BrowserRouter>
        <Routes>
          <Route element={<Layout />}>
            <Route index element={<App />} />
            <Route path="cartas" element={<Catalog />} />
            <Route path="jogar" element={<PlayPage />} />
            <Route path="colecao" element={<CollectionPage />} />
            <Route path="loja" element={<ShopPage />} />
            <Route path="loja/conversor" element={<ConverterPage />} />
            <Route path="desafios" element={<ChallengesPage />} />
            <Route path="personagens" element={<CharactersPage />} />
            <Route path="decks" element={<DecksPage />} />
            <Route path="decks/:id" element={<DeckEditPage />} />
            <Route path="salas" element={<RoomsPage />} />
            <Route path="salas/:code" element={<RoomPage />} />
            <Route path="duelo/:id" element={<DuelPage />} />
            <Route path="duelo/:id/replay" element={<ReplayPage />} />
            <Route path="entrar" element={<LogInPage />} />
            <Route path="conta" element={<AccountPage />} />
            <Route path="cadastro" element={<SignUpPage />} />
            <Route path="esqueci-a-senha" element={<ForgotPasswordPage />} />
            <Route path="nova-senha" element={<NewPasswordPage />} />
            <Route path="verificar-email" element={<VerifyEmailPage />} />
            <Route path="termos" element={<TermsPage />} />
            <Route path="privacidade" element={<PrivacyPage />} />
            <Route path="*" element={<NotFound />} />
          </Route>
        </Routes>
      </BrowserRouter>
    </QueryClientProvider>
  </StrictMode>,
);
