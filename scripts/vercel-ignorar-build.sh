#!/usr/bin/env bash
# A Vercel roda este script antes de cada build: está em Settings → Git → Ignored Build
# Step do projeto. Não pode ficar no vercel.json, porque com "services" a Vercel não
# aceita o "ignoreCommand" no topo do arquivo (recusou o primeiro deploy).
#   saída 0 = pula o build (nenhum deploy novo);
#   saída 1 = faz o build e publica.
#
# Por quê: no plano gratuito, cada deploy guarda uma cópia da imagem do container
# e o espaço para isso (Function Storage, 10 GB na conta toda) é limitado. Só vale
# publicar quando muda algo que vai para o ar.
#
# As prévias (branches que não são a main) já vêm desligadas pelo
# git.deploymentEnabled do vercel.json; a checagem do VERCEL_ENV é uma garantia.

if [ "$VERCEL_ENV" != "production" ]; then
  echo "Não é produção: sem deploy (a CI já testa o backend, o container e o front)."
  exit 0
fi

# HEAD^ é o commit anterior da main. O ":!" tira da comparação o que não vai para o
# ar: testes, documentação e os testes de navegador do front.
if git diff --quiet HEAD^ HEAD -- backend frontend vercel.json \
  ':!backend/test' ':!frontend/e2e' ':!frontend/src/**/*.test.ts' ':!**/*.md'; then
  echo "Nada do backend, do front ou do vercel.json mudou: sem deploy."
  exit 0
fi

echo "O backend, o front ou o vercel.json mudou: publicando."
exit 1
