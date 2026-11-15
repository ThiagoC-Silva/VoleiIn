# Código comum das Edge Functions

- `http.ts`: respostas de sucesso e de erro no formato do `docs/contratos-api.md` (seção 1), o token
  do header `Authorization` e o log estruturado sem dados pessoais (`docs/arquitetura-app.md`,
  14.5).

Aqui entram também os serviços externos (Claude API, FCM) atrás de uma interface, trocada por um
dublê nos testes (`docs/arquitetura-app.md`, seção 14.5).
