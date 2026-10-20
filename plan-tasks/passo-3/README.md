# Passo 3 — Autenticação

Quebra do passo 3 de [`docs/stack.md`](../../docs/stack.md) em tasks menores. Cada task fecha com um commit próprio; o passo fecha na T10, com a entrada em [`docs/progresso.md`](../../docs/progresso.md).

> Projeto Supabase, Brevo como SMTP, código de seis dígitos e cinco minutos, gatilho de criação do perfil, telas de entrar e de trocar o e-mail.

## Diagnóstico de 2026-10-19

Quase todo o código do passo já existia no working tree, sem commit e sem projeto remoto (`supabase link` nunca rodou). Foi commitado e enviado ao GitHub em seguida (`9814aa7` a `56de0ae`); o que falta em cada task está no arquivo dela. As três suítes SQL passam (schema 61, rls 69, autenticacao 16) e os 4 testes de widget da tela de entrar passam.

Decisões tomadas na abertura:
- `minSdk` é **24**, não 23: o Flutter 3.47.7 instalado já não dá suporte ao Android 6. Corrigir `docs/stack.md` e `app/CLAUDE.md` (T01).
- **Sem especificação de tela** no passo 3: as telas são codadas direto e o design será refeito depois. Registrar como "Aberto" no fechamento (T10).
- `plan-tasks/` fica versionado, com uma subpasta por passo.

## Tasks

| # | Task | Estado | Depende de |
| --- | --- | --- | --- |
| [T01](01-documentacao.md) | Fechar a documentação de autenticação | feito | — |
| [T02](02-config-auth-local.md) | Configuração local do Supabase Auth e modelos de e-mail | parcial | T01 |
| [T03](03-migracao-autenticacao.md) | Migração `autenticacao` e asserções | feito | T01 |
| [T04](04-base-app-flutter.md) | Base do app Flutter | feito | T01 |
| [T05](05-tela-entrar.md) | Tela de entrar (RF01) | parcial | T04 |
| [T06](06-tela-trocar-email.md) | Tela de trocar e-mail (RF35) | parcial | T04 |
| [T07](07-e2e-local.md) | Validação ponta a ponta no Supabase local | a fazer | T02, T03, T05, T06 |
| [T08](08-projeto-remoto-brevo.md) | Projeto Supabase remoto e Brevo como SMTP | a fazer | T07 |
| [T09](09-e2e-remoto.md) | Validação ponta a ponta no remoto | a fazer | T08 |
| [T10](10-fechamento.md) | Fechamento do passo | a fazer | T09 |

Ordem: T01 → T02 e T03 → T04 → T05 e T06 → T07 → T08 → T09 → T10.

Ao concluir uma task, troque o estado nesta tabela e no cabeçalho do arquivo dela.

## Modelo de task

```
# T0N — Nome
**Estado:** feito | parcial | a fazer · **Depende de:** T0x
## Objetivo
## O que já existe
## O que falta
## Pronto quando
## Commit
```
