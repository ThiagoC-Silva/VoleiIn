# T08 — Projeto Supabase remoto e Resend como SMTP

**Estado:** feito · **Depende de:** T07

Execução quebrada em tasks, uma por vez: [`plan-tasks/planT08/`](../planT08/README.md). Este arquivo guarda o que a T08 entrega; lá ficam a ordem, as decisões abertas e o resultado de cada etapa.

## Objetivo

Levar o passo 3 ao projeto remoto, em plano gratuito, com o Resend como SMTP próprio do Supabase Auth: o SMTP embutido do plano gratuito serve só para teste. Custo: R$ 0 de mensalidade, sobre o domínio `voleiin.com.br` já registrado (R$ 40 por ano).

Os itens marcados **[Thiago]** exigem conta, painel ou DNS e são feitos à mão.

## O que falta

### Supabase

- [x] **[Thiago]** Criar o projeto no plano gratuito, região São Paulo (`sa-east-1`). Guardar a senha do banco fora do repositório.
- [x] `supabase link --project-ref <ref>`.
- [x] `supabase db push` — aplica `enums`, `tabelas`, `indices`, `rls`, `autenticacao`. Os comentários da migração já foram corrigidos (`51b3b35`); depois daqui ela não pode mais ser editada.
- [x] Rodar o `seed.sql` no remoto só se for útil para teste; ele ainda é provisório. Não rodado (T08.4).
- [x] Configuração do Auth no remoto, pelo painel ou `supabase config push` (conferir o diff antes de aceitar):
  - OTP de 6 dígitos, validade de 300 s;
  - intervalo mínimo de 60 s entre envios; teto de 30 e-mails por hora;
  - senha mínima de 8 caracteres, sem requisitos de composição; "Leaked password protection" fica desligada, porque é recurso pago;
  - "Secure email change" desligado (`double_confirm_changes = false`);
  - "Secure password change" **ligado** (`secure_password_change = true`);
  - "Confirm email" **ligado** (`enable_confirmations = true`). Sem ele, o perfil nasce antes do código e a vinculação do Google entrega a conta de um impostor (`docs/stack.md`, Autenticação);
  - os modelos de confirmação, redefinição de senha e troca de e-mail, mais os avisos de e-mail trocado e de senha trocada, com os assuntos de `config.toml`. O de magic link fica no padrão do serviço.

### Google

- [x] **[Thiago]** No painel do Supabase, Authentication → Providers → Google:
  - ligar o provedor;
  - Client ID do cliente web da T11, e o do Android também, se o painel pedir a lista;
  - Client Secret do cliente web;
  - URL de retorno não precisa: o fluxo é por ID token, sem navegador;
  - "Skip nonce check" só se a T09 mostrar que o token chega sem nonce e o serviço o recusa. Ligado já na T08.6, igual ao local: o app não manda nonce, e é o único caminho validado no celular.

### Resend

- [x] **[Thiago]** Criar a conta gratuita (3.000 e-mails por mês, teto de 100 por dia).
- [x] **[Thiago]** Verificar o domínio do remetente no Resend, publicando no DNS do `voleiin.com.br` os registros que ele gerar. Sem domínio verificado, o Resend só envia para o e-mail do dono da conta.
- [x] **[Thiago]** No DNS, afrouxar o `_dmarc` para `p=none` durante a configuração e voltar a `p=reject` depois do envio real passar. O Registro.br publica a zona travada contra envio (`v=spf1 -all`, `MX 0 .`, `p=reject`).
- [x] **[Thiago]** No painel do Supabase, Authentication → SMTP: host `smtp.resend.com`, porta, usuário `resend` e a chave de API como senha, nome do remetente "VoleiIn". A chave não entra no `config.toml` nem em nenhum arquivo versionado.

### Limites

- [x] Conferir nas páginas de preço do Supabase e do Resend que os limites de `docs/stack.md` continuam valendo.

## Pronto quando

- `supabase migration list` mostra as cinco migrações nos dois lados.
- Um cadastro no remoto recebe o código por e-mail real, na caixa de entrada, com o modelo em português, e com SPF e DKIM passando.
- O provedor Google aparece ligado no painel.

## Commit

Sem arquivo novo esperado. Se `supabase config push` ou o link mudarem algo versionado, commitar: `Liga o projeto remoto e o SMTP do Resend`.
