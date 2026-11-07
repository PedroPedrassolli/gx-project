<!--
Título do PR: comece com a chave do card, ex.: "GXP-14: adiciona a loja".
O jira.yml usa essa chave para mover o card: abrir o PR → "Em análise"; merge → "Concluído".

Merge automático (auto-merge.yml): o PR entra sozinho na main quando a CI passa no commit
atual e ele está atualizado com a main. Para segurar, use o rótulo "segurar" ou abra como
rascunho.
-->

## Card

GXP-

## O que muda

-

## Como testar

-

## Checklist

- [ ] Testes novos ou atualizados (engine, economia, loja e validação de deck: teste primeiro)
- [ ] Tela nova ou alterada? Playwright + axe cobrindo a tela
- [ ] Mudou a engine (`ygopro-core` ou `CardScripts`)? PR à parte, com os testes de contrato passando
- [ ] Serviço novo ou uso maior de algum plano gratuito? Conta do custo mensal neste PR
