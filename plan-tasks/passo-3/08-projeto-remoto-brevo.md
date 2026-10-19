# T08 — Projeto Supabase remoto e Brevo como SMTP

**Estado:** a fazer · **Depende de:** T07

## Objetivo

Levar o passo 3 ao projeto remoto, em plano gratuito, com o Brevo como SMTP próprio do Supabase Auth: o SMTP embutido do plano gratuito serve só para teste. Custo: R$ 0.

Os itens marcados **[Thiago]** exigem conta, painel ou DNS e são feitos à mão.

## O que falta

### Supabase

- [ ] **[Thiago]** Criar o projeto no plano gratuito, região São Paulo (`sa-east-1`). Guardar a senha do banco fora do repositório.
- [ ] `supabase link --project-ref <ref>`.
- [ ] `supabase db push` — aplica `enums`, `tabelas`, `indices`, `rls`, `autenticacao`. Antes, confirmar que a T03 corrigiu os comentários da migração: depois daqui ela não pode mais ser editada.
- [ ] Rodar o `seed.sql` no remoto só se for útil para teste; ele ainda é provisório.
- [ ] Configuração do Auth no remoto, pelo painel ou `supabase config push` (conferir o diff antes de aceitar):
  - OTP de 6 dígitos, validade de 300 s;
  - intervalo mínimo de 60 s entre envios; teto de 30 e-mails por hora;
  - "Secure email change" desligado (`double_confirm_changes = false`);
  - os três modelos e o aviso de e-mail trocado, com os assuntos de `config.toml`.

### Brevo

- [ ] **[Thiago]** Criar a conta gratuita (300 e-mails por dia). Se exigir aprovação antes de liberar o SMTP, a alternativa é o Resend (3.000 por mês, teto de 100 por dia, pede cartão sem cobrar).
- [ ] **[Thiago]** Remetente: domínio próprio com SPF e DKIM no DNS, ou endereço verificado. Sem autenticação de domínio, o código tende a cair no spam.
- [ ] **[Thiago]** No painel do Supabase, Authentication → SMTP: host, porta, usuário e chave SMTP do Brevo, nome do remetente "VoleiIn". A chave não entra no `config.toml` nem em nenhum arquivo versionado.

### Limites

- [ ] Conferir nas páginas de preço do Supabase e do Brevo que os limites de `docs/stack.md` continuam valendo.

## Pronto quando

- `supabase migration list` mostra as cinco migrações nos dois lados.
- Um pedido de código no remoto chega por e-mail real, com o modelo em português.

## Commit

Sem arquivo novo esperado. Se `supabase config push` ou o link mudarem algo versionado, commitar: `Liga o projeto remoto e o SMTP do Brevo`.
