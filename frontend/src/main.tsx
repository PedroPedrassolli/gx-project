import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { BrowserRouter, Route, Routes } from "react-router";
import { App } from "./App.tsx";
import { Catalog } from "./catalog/Catalog.tsx";
import { Layout, NotFound } from "./Layout.tsx";
import "./styles.css";

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
            <Route path="*" element={<NotFound />} />
          </Route>
        </Routes>
      </BrowserRouter>
    </QueryClientProvider>
  </StrictMode>,
);
