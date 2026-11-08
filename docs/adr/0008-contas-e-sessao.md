# ADR 0008: Contas e sessão

- **Data:** 08/11/2026
- **Situação:** aceita (GXP-31).

## Contexto

O escopo pede cadastro aberto a partir dos 13 anos, guardando só a faixa de idade (3.1),
apelido único com filtro de palavrões (3.1), sessão em cookie `SameSite` com token CSRF e
limite de tentativas com Rack::Attack (6). O front e a API estão no mesmo domínio (ADR
0007). Faltava escolher como fazer cada parte, sem gastar o que os planos grátis não dão.

## Decisão

1. **Senha:** `has_secure_password` (bcrypt), de 8 caracteres a 72 bytes (o limite do
   bcrypt). Sem regra de maiúscula ou símbolo: tamanho protege mais e irrita menos (NIST
   SP 800-63B).
2. **Sessão:** como o gerador de autenticação do Rails 8. Cada login cria uma linha em
   `sessions`, e o cookie assinado `session_id` guarda o id dela: `httponly`,
   `SameSite=Lax`, `Secure` em produção, sem data para expirar. Sair apaga a linha. A tabela
   não guarda IP nem navegador: não precisamos desses dados (LGPD, minimização).
3. **CSRF:** `protect_from_forgery with: :exception`, com o token na sessão do Rails (o
   cookie criptografado `_gx_session`, `httponly`, `SameSite=Lax`), que o modo API não traz
   e voltou só para isso. O front pega o token em `GET /api/session` e manda no cabeçalho
   `X-CSRF-Token` em todo pedido que muda algo; sem ele, 403. As rotas do catálogo só leem
   e não mexem na sessão, então não criam cookie e a CDN continua guardando as respostas.
4. **Idade:** o cadastro recebe a data de nascimento, calcula os anos completos no dia de
   hoje em São Paulo e guarda só a faixa: `13-17` ou `18+`. Menos de 13 anos (ou data no
   futuro) recebe erro e nada é gravado. A data não aparece no log (`filter_parameters`).
5. **E-mail:** guardado sem espaços e em minúsculas, único. A verificação vem no GXP-35.
6. **Apelido:** de 3 a 20 caracteres, só letras sem acento, números, `_` e `-`; único sem
   diferenciar maiúsculas (índice em `lower(nickname)`). O filtro usa uma lista curta e
   nossa, em `config/nickname_blocklist.yml`: palavrões e ofensas comuns em português e
   inglês. Lê número no lugar de letra (`p0rra`) e separa camelCase. Palavra de 5 letras ou
   mais é barrada em qualquer parte; palavra curta, só quando aparece separada, para não
   barrar nome comum ("Paulo", "Ana_Lima"). O que escapar fica com a denúncia (F7).
7. **Limite de tentativas:** Rack::Attack, como pede o escopo, contando no próprio Postgres
   com o Solid Cache, o cache padrão do Rails 8. A memória de cada instância da Vercel não
   é dividida entre elas e se perde quando a instância para, então um contador em memória
   não segura quem tenta senhas. Limites: login, 5 por minuto por e-mail e 30 por minuto por
   IP; cadastro, 10 por hora por IP (escola e casa dividem IP). Acima disso, 429.
8. **Rotas:** `GET /api/session` (o usuário, ou `null`, e o token CSRF), `POST
   /api/session` (entrar), `DELETE /api/session` (sair) e `POST /api/registrations`
   (cadastro, já entra). Erro de validação volta com 422 e as mensagens em português por
   campo. Login errado diz só "e-mail ou senha incorretos", sem contar qual dos dois.

9. **E-mail (GXP-35):** pelo SMTP do Brevo (ADR 0004), com `deliver_now`: a Vercel não
   tem fila de jobs. Se o envio falhar, a conta não volta atrás; a pessoa pede de novo. O
   link de confirmação vale 2 dias e deixa de valer se o e-mail mudar
   (`generates_token_for`); o de troca de senha vale 1 hora e deixa de valer depois da troca
   (`has_secure_password`). Limites: reenvio da confirmação, 5 por hora por IP; pedido de
   troca de senha, 5 por hora por e-mail e 20 por IP. Os dados do Brevo ficam nos secrets
   do GitHub `BREVO_SMTP_LOGIN`, `BREVO_SMTP_KEY` e `MAIL_FROM` (só o endereço do
   remetente verificado), e o workflow *E-mail na Vercel* copia para a Vercel e publica de
   novo. Sem a chave, nada sai e o envio só aparece no log.

## Alternativas consideradas

- **Token no `localStorage` (JWT):** qualquer script na página lê o token; o cookie
  `httponly` não. E sair de verdade pede guardar os tokens revogados de qualquer jeito.
- **`rate_limit` do Rails 8:** faz o mesmo nos controllers, mas o escopo pede Rack::Attack, e
  ele barra antes de chegar ao Rails (gasta menos CPU da Vercel). Os dois precisam do mesmo
  contador dividido entre as instâncias.
- **Lista pública de palavrões (LDNOOBW, CC BY 4.0):** a de português barra palavras comuns
  ("aranha", "cerveja", "inferno") e identidades ("lésbica", "bissexual"); a de inglês tem
  400 termos e muito falso positivo. Uma lista nossa e curta erra menos.

## Consequências

- Uma linha no banco por login, e um contador no Solid Cache por tentativa: bem abaixo
  dos 500 MB do Supabase.
- O front precisa buscar o token CSRF antes do primeiro POST e mandar o cabeçalho em todos.
- Mudar a faixa de idade depois exige pedir a data de novo: ela não fica guardada.
