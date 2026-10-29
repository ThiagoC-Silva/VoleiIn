# Passo 3 — Autenticação

Quebra do passo 3 de [`docs/stack.md`](../../docs/stack.md) em tasks menores. Cada task fecha com um commit próprio; o passo fecha na T10, com a entrada em [`docs/progresso.md`](../../docs/progresso.md).

> Projeto no Supabase, Resend como SMTP, e-mail e senha com código de seis dígitos e cinco minutos no cadastro, na redefinição e na troca de e-mail, cliente OAuth do Google, gatilhos de criação do perfil e de revogação dos aparelhos, telas de entrar, de redefinir a senha e de trocar o e-mail.

## Diagnóstico de 2026-10-19

Quase todo o código do passo já existia no working tree, sem commit e sem projeto remoto (`supabase link` nunca rodou). Foi commitado e enviado ao GitHub em seguida (`9814aa7` a `56de0ae`); o que falta em cada task está no arquivo dela. As três suítes SQL passam (schema 61, rls 69, autenticacao 16) e os 4 testes de widget da tela de entrar passam.

Decisões tomadas na abertura:
- `minSdk` é **24**, não 23: o Flutter 3.47.7 instalado já não dá suporte ao Android 6. Corrigir `docs/stack.md` e `app/CLAUDE.md` (T01).
- **Sem especificação de tela** no passo 3: as telas são codadas direto e o design será refeito depois. Registrar como "Aberto" no fechamento (T10).
- `plan-tasks/` fica versionado, com uma subpasta por passo.

## Decisões de 2026-10-20

- **O perfil só nasce na confirmação do primeiro código.** A sonda da T02 mostrou que, com a autoconfirmação ligada, conta pedida e nunca confirmada já ficava confirmada e com `pessoa`. Agora `enable_confirmations = true` e o gatilho cria `pessoa` quando `email_confirmed_at` é preenchido; o nome segue conferido no pedido (`docs/stack.md`, Autenticação). Reabre T02 e T03, ajusta T07 e T08.
- A T07 roda em dois trilhos: um script versionado pela API do Auth (`supabase/testes/autenticacao_api.sh`, reaproveitado na T09) e o celular físico, porque não há emulador nesta máquina.

## Decisões de 2026-10-20 — senha e Google

O acesso deixou de ser por código a cada entrada: passa a ser **e-mail e senha, ou conta Google** (`docs/prd.md`, RF01, RF41 e RN21; `docs/stack.md`, Autenticação; commit `84f20aa`). O motivo foi o atrito de buscar um código a cada entrada, a turma já usar Google no Android e cada entrada gastar cota do SMTP.

- O código de seis dígitos fica só onde prova a posse do e-mail: confirmação do cadastro com senha (uma vez), redefinição de senha e troca de e-mail.
- **O cadastro com senha confirma por código**, e o perfil só nasce na confirmação. Isso absorve a decisão anterior, ainda não implementada, e ganha um motivo: sem confirmação, a vinculação automática do Google entregaria à dona do e-mail a conta de um impostor com a senha dele valendo.
- **Google**: nome de exibição vem do Google (`full_name` ou `name`), sem perguntar; a foto não é copiada. Mesmo e-mail é a mesma conta. Nativo, pelo `google_sign_in` e `signInWithIdToken`.
- **Senha esquecida e troca de senha** são o mesmo caminho, por código no e-mail (RF41). Ao concluir, as outras sessões caem, os aparelhos de push são apagados e o e-mail recebe aviso de senha trocada.
- Senha de no mínimo 8 caracteres, sem regra de composição; checagem de senha vazada fica fora, por ser paga. `secure_password_change = true`.

Efeito nas tasks: T01 reaberta e fechada no mesmo dia; T02, T03, T04 e T07 a T10 reabertas; T05 reescrita; T06 sem mudança de código; T11 (Google Cloud) e T12 (senha) novas. A numeração antiga fica, porque commits já citam "T05" e "T06".

## Decisões de 2026-10-20 — tela de consentimento em teste

O Google recusou publicar a tela de consentimento sem página inicial e Política de Privacidade, e o VoleiIn ainda não tem nenhuma das duas. Decidido: ela fica **em teste** até o passo 10, com as contas de desenvolvimento como usuárias de teste (até 100). Nos passos 3 a 9 só elas usam o app, e quem não está na lista continua entrando com e-mail e senha. A publicação, com as duas páginas no GitHub Pages, passa a fazer parte do passo 10, antes de o APK chegar à turma (`docs/stack.md`, Autenticação, Riscos e Ordem de implementação). O texto da Política de Privacidade é decisão de produto, a fechar no passo 10.

## Decisões de 2026-10-26 — cadastro refeito

A T07 mostrou que, quando um cadastro pendente é refeito antes do código, o serviço fica com a senha e o nome do primeiro pedido. Se o primeiro pedido for de um impostor, a dona do e-mail confirma pelo código e a senha dele entra na conta dela. É a tomada de conta que o cadastro confirmado por código devia fechar, só que pela tela de criar conta e não pelo Google. Decidido: a A3 aberta pela A2 grava, depois do código, a senha e o nome digitados (`docs/prd.md`, RN21 e decisão "Cadastro com senha"; `docs/stack.md`, Autenticação). A implementação é a T13, antes da T08, para a T09 conferir no remoto.

## Decisões de 2026-10-28 — teto de e-mails

A T09.8 mostrou que o teto de 30 e-mails por hora chega ao app com o mesmo `over_email_send_rate_limit` do intervalo de 60 s. Os dois viram "Aguarde um minuto…", e a A1 engole a recusa e abre a A3 esperando um código que não vem. Decidido: o app separa os dois pelo `msg`, e o teto ganha a mensagem "Muitos códigos enviados agora. Tente de novo em até uma hora.", sem a A1 abrir a A3. A correção é a T14, antes da T10, para o passo 3 não fechar com um defeito conhecido na autenticação.

## Tasks

| # | Task | Estado | Depende de |
| --- | --- | --- | --- |
| [T01](01-documentacao.md) | Fechar a documentação de autenticação | feito | — |
| [T02](02-config-auth-local.md) | Configuração local do Supabase Auth e modelos de e-mail | feito | T01 |
| [T03](03-migracao-autenticacao.md) | Migração `autenticacao` e asserções | feito | T01 |
| [T04](04-base-app-flutter.md) | Base do app Flutter | feito | T01, T11 |
| [T05](05-tela-entrar.md) | Tela de entrar (RF01) | feito | T02, T03, T04 |
| [T06](06-tela-trocar-email.md) | Tela de trocar e-mail (RF35) | feito | T04 |
| [T07](07-e2e-local.md) | Validação ponta a ponta no Supabase local | feito | T02, T03, T05, T06, T11, T12 |
| [T08](08-projeto-remoto-resend.md) | Projeto Supabase remoto e Resend como SMTP | feito | T07 |
| [T09](09-e2e-remoto.md) | Validação ponta a ponta no remoto | feito | T08, T13 |
| [T10](10-fechamento.md) | Fechamento do passo | feito | T09, T14 |
| [T11](11-google-cloud.md) | Projeto no Google Cloud e provedor Google local | feito | T01 |
| [T12](12-redefinir-senha.md) | Redefinição e troca de senha (RF41) | feito | T05 |
| [T13](13-cadastro-refeito.md) | Nome e senha do cadastro refeito | feito | T07 |
| [T14](14-teto-de-emails.md) | Mensagem do teto de e-mails por hora | feito | T09 |

Ordem: T01 → T02 e T03 → T11 → T04 → T05 → T12 → T07 → T13 → T08 → T09 → T14 → T10. A reabertura de T02 e T03 é um commit só.

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
