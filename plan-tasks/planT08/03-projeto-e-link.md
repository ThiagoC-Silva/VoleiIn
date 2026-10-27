# T08.3 — Criar o projeto remoto e ligar o CLI

**Estado:** feito · **Depende de:** T08.1

## Objetivo

Ter o projeto VoleiIn no Supabase, plano gratuito, região São Paulo, e o CLI desta máquina ligado a ele.

## O que já existe

- Supabase CLI `3.0.0-next.20`.
- `supabase/.temp/` no `.gitignore`, onde o `link` grava o ref.
- A migração `rls` revoga os privilégios padrão: tabela ou função nova nasce sem acesso para `anon`, `authenticated` e `public` (`docs/progresso.md`, passo 2).

## O que falta

- [ ] **[Thiago]** Criar o projeto:
  - plano gratuito, região São Paulo (`sa-east-1`);
  - senha do banco forte, guardada fora do repositório;
  - anotar as opções que a tela de criação oferecer (Data API, exposição automática de tabelas novas, RLS automática ou outras) e o que foi marcado. Na dúvida, deixar o padrão: as migrações revogam os privilégios por conta própria, e a T08.4 confere.
- [ ] **[Thiago]** `! supabase login`, se o CLI ainda não tiver token.
- [ ] **[Thiago]** `! supabase link --project-ref <ref>`, que pede a senha do banco.
- [ ] `supabase projects list` mostra o projeto ligado.
- [ ] `git status` sem nada novo: o que o `link` gravou fica em `supabase/.temp/`.
- [ ] Anotar aqui o ref e a URL do projeto, que não são segredo: vão dentro do APK da T09.

## Resultado

Feito em 2026-10-27.

- Projeto **VoleiIn**, plano gratuito, região `sa-east-1`, Postgres 17, `ACTIVE_HEALTHY`.
- **Ref:** `zmokpmovphikmobynssy`. **URL:** `https://zmokpmovphikmobynssy.supabase.co`. Não são segredo: vão dentro do APK da T09.
- Opções da tela de criação: **Data API marcada**; **exposição automática de tabelas desmarcada**; **RLS automática desmarcada**. Com a exposição desmarcada, tabela nova não ganha privilégio para a API por padrão, o que combina com a migração `rls`; a T08.4 confere os privilégios depois do `db push`.
- `supabase login` feito em outro terminal, porque o modo `!`/`<bash-input>` do Claude Code não tem TTY. `supabase link --project-ref zmokpmovphikmobynssy` feito; `supabase projects list` mostra `"linked": true`.
- `git status` sem nada novo do `link`: o ref fica em `supabase/.temp/`, ignorado.
- Servidor MCP do Supabase registrado em `.mcp.json` (escopo de projeto, com `project_ref`), que entrou no `.gitignore` por ser configuração local.

## Pronto quando

O projeto existe em `sa-east-1` no plano gratuito, `supabase projects list` o mostra ligado, e `git status` não mudou.

## Commit

`Registra a criação do projeto remoto`, só com o registro desta task.
