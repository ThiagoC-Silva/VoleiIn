# T08.1 — Conferir os limites dos planos gratuitos

**Estado:** feito · **Depende de:** —

## Objetivo

Confirmar, antes de criar as contas, que os limites em que o `docs/stack.md` se apoia continuam valendo. É o tratamento do risco "Os limites acima mudam sem aviso" (`docs/stack.md`, Riscos e limites do plano gratuito).

## O que já existe

- `docs/stack.md`, tabela de serviços e de riscos:
  - Supabase: R$ 0 até 500 MB de banco e 1 GB de arquivos; pausa após uma semana sem atividade;
  - Brevo: 300 mensagens por dia, R$ 0;
  - Resend, a alternativa: 3.000 por mês, teto de 100 por dia, pede cartão sem cobrar.
- A configuração do Auth depende de: `otp_expiry = 300`, `max_frequency = "60s"`, `rate_limit.email_sent = 30` e "Leaked password protection" fora do plano gratuito.

## O que falta

- [x] Ler as páginas de preço do Supabase, do Brevo e do Resend, e a documentação de limites do Supabase Auth.
- [x] Para cada limite acima: confirmado, mudou (para quanto) ou não achado.
- [x] Conferir no plano gratuito do Supabase:
  - quantos projetos ativos cabem;
  - se a região São Paulo (`sa-east-1`) está disponível;
  - se SMTP próprio e o ajuste de `email_sent` estão liberados;
  - se a checagem de senha vazada continua paga.
- [x] Conferir no Brevo gratuito: se o SMTP exige aprovação da conta, se o remetente precisa de domínio próprio e se a marca do Brevo entra no e-mail.
- [x] Se algum limite mudou a ponto de afetar custo ou regra, **parar** e levar ao Thiago antes da T08.2: muda o `docs/stack.md` primeiro.

## Resultado

Conferido em 2026-10-26, nas páginas oficiais. Onde a fonte é de terceiros, está dito.

### Supabase, plano gratuito — tudo confirmado

| Limite | Situação | Fonte |
| --- | --- | --- |
| 500 MB de banco por projeto | confirmado | [supabase.com/pricing](https://supabase.com/pricing) |
| 1 GB de arquivos | confirmado | idem |
| 50 mil contas ativas por mês | confirmado | idem |
| 500 mil chamadas de Edge Function por mês | confirmado | idem |
| Pausa após uma semana sem atividade | confirmado | idem |
| Projetos ativos | 2 por conta: cabe o VoleiIn | idem |
| SMTP próprio | incluído no gratuito | idem |
| Checagem de senha vazada | só a partir do Pro: continua fora | idem e [password-security](https://supabase.com/docs/guides/auth/password-security) |
| Região São Paulo (`sa-east-1`) | listada, sem restrição por plano | [platform/regions](https://supabase.com/docs/guides/platform/regions) |
| SMTP embutido | 2 e-mails por hora, só para a equipe do projeto | [auth-smtp](https://supabase.com/docs/guides/auth/auth-smtp) |
| `email_sent` | com SMTP próprio, começa em 30 por hora e pode ser ajustado; sem ele, não muda | [auth-smtp](https://supabase.com/docs/guides/auth/auth-smtp) e [rate-limits](https://supabase.com/docs/guides/auth/rate-limits) |
| 60 s entre envios ao mesmo e-mail | é o padrão do serviço e pode ser ajustado | [rate-limits](https://supabase.com/docs/guides/auth/rate-limits) |

### Brevo, plano gratuito — o custo muda

| Ponto | Situação | Fonte |
| --- | --- | --- |
| 300 e-mails por dia, R$ 0, sem cartão | confirmado | [brevo.com/pricing](https://www.brevo.com/pricing/) e [free-smtp-server](https://www.brevo.com/free-smtp-server) |
| Aprovação da conta | **exigida sempre**: "Once we approve your account for sending, you can start sending up to 300 emails per day" | [brevo.com/pricing](https://www.brevo.com/pricing/), FAQ |
| Domínio próprio | **exigido**. O passo a passo do SMTP é "Add and verify your domain in the Senders and IPs section" e, depois, pedir a ativação do SMTP ao suporte, dizendo se é marketing ou transacional. Em outra página: "Brevo needs a configured sender and domain before the first send" | [free-smtp-server](https://www.brevo.com/free-smtp-server) e [brevo.com/resend](https://www.brevo.com/resend/) |
| Endereço verificado de webmail (gmail.com) no lugar do domínio | não serve. Fontes de terceiros dizem que o Brevo não autentica domínio de webmail e troca o remetente por `brevosend.com` sem avisar | [suped.com](https://www.suped.com/learn/dmarc/how-to-set-up-dmarc-dkim-spf-for-brevo) e [palisade.email](https://www.palisade.email/email-deliverability/why-are-brevo-emails-going-to-spam) |
| Rodapé "Sent with Brevo" | a remoção é recurso pago ("No Brevo logo"). Não achei se vale para o transacional por SMTP: conferir no e-mail real da T08.7 | [brevo.com/pricing](https://www.brevo.com/pricing/) |

### Resend, a alternativa — também exige domínio

| Ponto | Situação | Fonte |
| --- | --- | --- |
| 3.000 por mês, teto de 100 por dia, R$ 0 | confirmado; 3 domínios no gratuito | [resend.com/pricing](https://resend.com/pricing) |
| Cartão | **não pede**, confirmado na prática em 26/10/2026: conta criada pelo GitHub, sem cartão. A fonte oficial não dizia, e as de terceiros divergiam | cadastro feito |
| Domínio próprio | **exigido** para mandar a quem não é o dono da conta: o domínio de teste `resend.dev` só envia ao e-mail da conta | [403-error-resend-dev-domain](https://resend.com/docs/knowledge-base/403-error-resend-dev-domain) |

### O que isso muda

O `docs/stack.md` diz "Envio de e-mail … R$ 0" e trata a aprovação do Brevo como motivo para ir ao Resend. Nas páginas de hoje:

- os dois provedores exigem um domínio próprio, então trocar de provedor não evita esse custo;
- o Brevo pede aprovação para qualquer conta, e o pedido só é feito depois de verificar o domínio.

Um `.com.br` direto no Registro.br custa R$ 40 por ano, segundo fontes de terceiros. A tabela oficial não abriu daqui: conferir em [registro.br](https://registro.br) antes de contratar.

### Decisão do Thiago, em 26/10/2026

- **Domínio `voleiin.com.br`**, registrado no Registro.br no mesmo dia, R$ 40 por ano, vencendo em 26/10/2027.
- **Provedor: Resend**, acionando a condição de escape que o `docs/stack.md` já previa, porque a aprovação manual do Brevo se confirmou obrigatória para toda conta.

O `docs/stack.md` foi atualizado: o Resend na tabela de serviços, a anuidade do domínio como gasto fixo, o teto de 100 por dia na tabela de riscos, o vencimento do domínio como risco novo e a data desta conferência.

## Pronto quando

Cada limite listado tem fonte e data, e o `docs/stack.md` está certo ou tem a mudança decidida.

## Commit

Se o `docs/stack.md` mudar: `Atualiza os limites dos planos gratuitos`. Se não: `Registra a conferência dos limites gratuitos`.
