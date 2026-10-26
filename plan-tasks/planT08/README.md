# Plano da T08 — Projeto Supabase remoto e Resend como SMTP

Quebra de [T08](../passo-3/08-projeto-remoto-resend.md) em tasks executadas **uma por vez**: a seguinte só começa quando a anterior está feita, com o estado trocado nesta tabela e no cabeçalho do arquivo dela. Cada task fecha com um commit próprio. Quando a task não muda código, o commit leva só o registro dela: o "Resultado", o estado e o que mais tiver mudado nos documentos do plano.

A exceção à fila é a espera do DNS: enquanto a verificação do domínio no Resend não sai (T08.2), a T08.3 e a T08.4 seguem, porque não dependem dela.

Os itens marcados **[Thiago]** exigem conta, painel, senha ou DNS e são feitos à mão. Comando que pede senha no terminal o Thiago roda com `! <comando>`, para a saída cair na conversa.

## Estado conferido em 2026-10-26

- T01 a T07, T11 e T12 feitas. A T13 (cadastro refeito) está a fazer e, pela ordem do [README do passo](../passo-3/README.md), vem antes da T08. Ela só muda o app e o script, sem migração, então não altera o que a T08 aplica; o que ela pede é estar pronta antes da T09.
- Cinco migrações em `supabase/migrations/`: `enums`, `tabelas`, `indices`, `rls`, `autenticacao`. Nunca aplicadas no remoto; `supabase link` nunca rodou.
- Supabase CLI `3.0.0-next.20`. O `config push` só envia o que o `config.toml` declara e mostra o diff de cada recurso antes de gravar; `supabase config diff` mostra o mesmo diff sem gravar.
- `config.toml` sem a seção `[auth.email.smtp]` (está comentada): o SMTP do remoto fica só no painel, e o `config push` não o toca.
- `rate_limit.email_sent = 30` exige SMTP próprio, segundo o próprio `config.toml`. Por isso o SMTP entra (T08.5) antes do `config push` (T08.6).
- `supabase/.temp/` está no `.gitignore`; é onde o `link` grava o ref.

## Decidido na T08.1

- **Provedor: Resend**, no lugar do Brevo. O Brevo exige aprovação manual de toda conta, que é a condição de escape já escrita no `docs/stack.md`. O Resend verifica o domínio e libera sozinho. Teto de 100 por dia, contra 300 do Brevo, muito acima do pico real.
- **Domínio: `voleiin.com.br`**, registrado no Registro.br em 26/10/2026, R$ 40 por ano, vencimento em 26/10/2027. Era inevitável: Brevo e Resend exigem domínio próprio autenticado. O `docs/stack.md` já registra o custo e a exigência.

## A decidir antes da execução

- **`skip_nonce_check` no remoto.** O `config.toml` tem `skip_nonce_check = true`, que o local pede para o Google, e o `config push` levaria isso ao remoto. A T08 dizia ligá-lo no remoto só se a T09 mostrar que é preciso. Decidir na T08.6, antes de aceitar o diff do Google.
- **`seed.sql` no remoto.** Proposta: não rodar. Ele ainda é provisório, com dois locais fictícios, e o passo 3 não usa local nem quadra. O `db push` não roda o seed sem `--include-seed`.

## Para a execução

- Senha do banco, chave SMTP e segredo do Google não entram em arquivo versionado nem nesta pasta. O ref do projeto e a URL não são segredo: vão dentro do APK.
- **Parar** se o `db push` falhar em alguma migração: não editar a migração. Corrigir criando a próxima e decidir com o Thiago.
- **Parar** se o diff do `config push` trouxer algo que não está na lista da T08.6.
- O teto de 30 e-mails por hora vale no remoto, dentro das 100 por dia do Resend. A T08.7 gasta um; a T09 precisa do resto.

## Tasks

| # | Task | Estado | Depende de |
| --- | --- | --- | --- |
| [T08.1](01-limites.md) | Conferir os limites dos planos gratuitos | feito | — |
| [T08.2](02-conta-resend.md) | Conta no Resend e domínio do remetente | a fazer | T08.1 |
| [T08.3](03-projeto-e-link.md) | Criar o projeto remoto e ligar o CLI | a fazer | T08.1 |
| [T08.4](04-migracoes.md) | Aplicar as migrações no remoto | a fazer | T08.3 |
| [T08.5](05-smtp.md) | SMTP do Resend no painel | a fazer | T08.2, T08.4 |
| [T08.6](06-config-auth.md) | Configuração do Auth e do Google pelo `config push` | a fazer | T08.5 |
| [T08.7](07-fumaca-e-registro.md) | Cadastro com e-mail real e fechamento da T08 | a fazer | T08.6 |

## Modelo de task

```
# T08.N — Nome
**Estado:** feito | parcial | a fazer · **Depende de:** T08.x
## Objetivo
## O que já existe
## O que falta
## Resultado        ← preenchido na execução
## Pronto quando
## Commit
```
