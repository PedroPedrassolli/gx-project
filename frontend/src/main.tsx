import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { App } from "./App.tsx";
import { Catalog } from "./catalog/Catalog.tsx";
import "./styles.css";

// Duas páginas por enquanto: o catálogo em /cartas e a inicial. A Vercel manda qualquer
// caminho para o index.html.
const page = location.pathname.replace(/\/$/, "") === "/cartas" ? <Catalog /> : <App />;

const root = document.getElementById("root");
if (!root) throw new Error("elemento #root não encontrado no index.html");

createRoot(root).render(<StrictMode>{page}</StrictMode>);
