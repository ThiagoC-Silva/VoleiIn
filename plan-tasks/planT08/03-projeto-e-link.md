# T08.3 — Criar o projeto remoto e ligar o CLI

**Estado:** a fazer · **Depende de:** T08.1

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

## Pronto quando

O projeto existe em `sa-east-1` no plano gratuito, `supabase projects list` o mostra ligado, e `git status` não mudou.

## Commit

`Registra a criação do projeto remoto`, só com o registro desta task.
