# Código comum das Edge Functions

- `http.ts`: respostas de sucesso e de erro no formato do `docs/contratos-api.md` (seção 1), o token
  do header `Authorization` e o log estruturado sem dados pessoais (`docs/arquitetura-app.md`,
  14.5).

Os serviços externos são trocados por um dublê nos testes (`docs/arquitetura-app.md`, seção 14.5). A
Claude API usa o próprio SDK (`@anthropic-ai/sdk`) como interface: a `process-receipt` recebe o
cliente pronto, e os testes o criam com o `baseURL` de um servidor local que imita a API
(`process-receipt/test_support.ts`). Nos fluxos do app, o mesmo papel é do `ANTHROPIC_BASE_URL`.
