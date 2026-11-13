# Testes contra o Supabase local

Testes Deno que precisam do Supabase de pé (`docs/arquitetura-app.md`, seção 14.4). No CI, rodam no
job `database`, depois do `supabase test db`; o job `functions` os ignora.

| Arquivo | Cenários | Fatia |
|---------|----------|-------|
| `avatars_test.ts` | A01 a A06, fotos de perfil (RN106) | 2 |
| `concurrency/*_test.ts` | Conexões separadas ao banco local | 4 em diante |

```bash
SUPABASE_URL=http://127.0.0.1:54321 SUPABASE_PUBLISHABLE_KEY=<chave de supabase status> \
  deno test --allow-net --allow-env _tests/
```
