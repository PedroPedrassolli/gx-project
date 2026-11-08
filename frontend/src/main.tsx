import { lazy, StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { BrowserRouter, Route, Routes } from "react-router";
import { App } from "./App.tsx";
import { Layout, NotFound } from "./Layout.tsx";
import "./styles.css";

// Cada página vira um arquivo JS baixado só quando a pessoa abre: a página inicial não
// carrega o código do catálogo nem do Deck Edit. O Layout mostra "Carregando…" enquanto isso.
const Catalog = lazy(() => import("./catalog/Catalog.tsx").then((m) => ({ default: m.Catalog })));
const CollectionPage = lazy(() =>
  import("./collection/CollectionPage.tsx").then((m) => ({ default: m.CollectionPage })),
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
            <Route path="colecao" element={<CollectionPage />} />
            <Route path="decks" element={<DecksPage />} />
            <Route path="decks/:id" element={<DeckEditPage />} />
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
