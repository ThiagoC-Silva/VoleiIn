# T14 — Mensagem do teto de e-mails por hora

**Estado:** a fazer · **Depende de:** T09

## Objetivo

Fazer o app separar o teto de e-mails por hora do intervalo de 60 s entre envios, achado na T09.8 e decidido pelo Thiago em 2026-10-28 ([T09](09-e2e-remoto.md), "Teto e as mensagens do app").

O caso: o teto de 30 e-mails por hora é do projeto inteiro, e o serviço o recusa com o mesmo `over_email_send_rate_limit` do intervalo de 60 s. O app trata os dois como o intervalo. A A2 e a A3 dizem "Aguarde um minuto antes de pedir outro código.", mas o teto só passa quando a hora vira. A A1, na entrada com senha de um cadastro pendente, engole a recusa e abre a A3 esperando um código que não vem. Ninguém real cai nisso antes do passo 10, mas o dia em que a turma instalar o app é o pico de cadastros.

A decisão:
- o app separa a recusa pelo `msg`. Se for o dos 60 s ("…after N seconds"), tudo fica como hoje: a A1 segue engolindo a recusa, porque o código de menos de um minuto vale;
- qualquer outro `msg` é o teto. A mensagem é **"Muitos códigos enviados agora. Tente de novo em até uma hora."**, e a A1 a mostra em vez de abrir a A3;
- custo aceito: a separação depende de um texto em inglês do Supabase Auth. Se o texto dos 60 s mudar, o caso dos 60 s passa a mostrar a mensagem do teto e a A1 para nele. É errado, mas não é silencioso.

Duas rodadas, como manda o `CLAUDE.md`: primeiro o texto nos documentos, com commit próprio; depois o código.

## O que já existe

- **Os dois `msg`, na v2.197.0**, a versão do local e do remoto:
  - no teto, "email rate limit exceeded", visto no remoto (T09.8);
  - nos 60 s, "For security purposes, you can only request this after 59 seconds.", sondado no local por um `/resend` logo depois do `/signup` (T09.8). O número é o que falta para o intervalo terminar.
- **O `gotrue` 2.27.3 põe o `msg` da resposta em `AuthException.message`** (`_getErrorMessage` em `fetch.dart`, que tenta `msg`, depois `message`). O código vai em `AuthException.code`.
- **Em `app/lib/dados/auth_repositorio.dart`, só dois lugares mudam:**
  - `entrar` engole todo `over_email_send_rate_limit` do `resend`, com o comentário "Um código enviado há menos de um minuto continua valendo";
  - `_traduzir` mapeia `over_email_send_rate_limit` para "Aguarde um minuto antes de pedir outro código.".
- **As telas não mudam.** Toda falha de `entrar` já aparece acima do "Entrar" e mantém a A1 (`entrar_tela.dart`, teste "senha recusada mostra a mensagem e fica na tela"). A A2, a A3, a A4 e a troca de e-mail mostram o que vier do `_traduzir`.
- **A tradução é uma só.** Por isso a mensagem do teto vale também na A4 (pedir e reenviar o código) e na troca de e-mail, que a decisão não citou. É o mesmo teto, e a mensagem não fala de tela.
- **O contador da A3 recomeça em 60 s depois de qualquer reenvio**, mesmo recusado (`ReenvioCodigo._reenviar`). No teto, isso deixa tentar de novo em um minuto e receber a mesma mensagem. Fica como está: mudar o contador seria desenho novo, e a recusa é do servidor.
- **Documentos:** os textos de erro das telas de acesso não estão em nenhum documento, só no código. O desenho não mostra erros; o `implementacao.md` de `01-acesso` diz onde aparecem, sem os textos. O `docs/stack.md`, em Autenticação, descreve os dois limites, mas não diz que eles recusam com o mesmo código.
- **O teto não se reproduz no local.** Sem SMTP próprio, o Auth local não aplica o `email_sent` (T07). O único lugar para ver o teto de verdade é o remoto, baixando-o no painel (T09.8).

## O que falta

### Rodada 1 — documentos

- [ ] `docs/stack.md`, Autenticação, no parágrafo dos limites: os dois limites recusam com o mesmo `over_email_send_rate_limit`, e só o `msg` os separa. O app trata como intervalo de 60 s a recusa cujo `msg` diz "after N seconds". Nesse caso a A1 segue para a etapa do código, porque o anterior ainda vale. Qualquer outra recusa é o teto, e nenhuma tela segue.
- [ ] `docs/stack.md`, Riscos: uma linha com o custo aceito. A separação depende do texto em inglês do serviço; se ele mudar, o intervalo de 60 s passa a mostrar a mensagem do teto. O tratamento é o cenário 8 do script, que confere o texto a cada rodada (abaixo).
- [ ] `docs/design/telas/01-acesso/implementacao.md`, em "Todas": as duas mensagens de limite de envio, com os textos exatos e onde aparecem. A A1 mostra a do teto acima do "Entrar" e não abre a A3. Vale também para a troca de e-mail, que está em "Fora das telas A".
- [ ] Ler `docs/prd.md` (RNF06 e as decisões de autenticação) e confirmar que nada muda nele. A RNF06 já diz "com limite de envios por e-mail a cada hora", e o texto da mensagem é de design, não de regra. Se algo pedir mudança, parar e perguntar.
- [ ] Commit: `Documenta a mensagem do teto de e-mails`.

### Rodada 2 — código

- [ ] `auth_repositorio.dart`: uma função que diz se a recusa é o intervalo de 60 s. Ela confere o `code` `over_email_send_rate_limit` e o `message` contendo `after <número> second`, para cobrir também "1 second". Usada em dois lugares:
  - `entrar` só engole a recusa quando ela é o intervalo; qualquer outra vai ao `_traduzir`. O comentário diz por quê;
  - `_traduzir`: intervalo → "Aguarde um minuto antes de pedir outro código."; outro `msg` → "Muitos códigos enviados agora. Tente de novo em até uma hora.".
- [ ] Testes do repositório (`app/test/dados/auth_repositorio_test.dart`), com um `GoTrueClient` falso como o `_AuthRecusaSenha` que já está lá:
  - `entrar` de cadastro pendente com o `resend` recusado pelo `msg` dos 60 s devolve `false`;
  - o mesmo com "email rate limit exceeded" lança `FalhaAuth` com a mensagem do teto;
  - `reenviarConfirmacao` (ou outra chamada que passe pelo `_traduzir`) com cada `msg` dá a mensagem certa;
  - um `msg` qualquer, que não é nenhum dos dois, cai no teto, e não no intervalo.
- [ ] Teste de widget da A1: `entrar` falhando com a mensagem do teto mostra o texto e não abre a A3. O `AuthFalso` já tem `falhaAoEntrar`.
- [ ] `supabase/testes/autenticacao_api.sh`, no 8 e no reenvio do 6: além do `error_code`, o `msg` tem `after <número> second`. É a guarda do custo aceito: se o Supabase mudar o texto, a rodada local falha antes de o app errar em produção. Rodar a suíte local inteira.
- [ ] `flutter test`, `dart analyze` e as suítes SQL passam.
- [ ] **No remoto, com um e-mail só.** APK release novo, como na T09.3, e o Claude operando o celular pelo `adb`. Com o teto em 30:
  1. `/signup` por `curl` a um endereço novo com `+` no Gmail 2. É o único e-mail da task.
  2. Em menos de 60 s, A1 com esse endereço e a senha dele: a A3 abre. Isso prova que o `msg` dos 60 s do remoto casa com o padrão, o que até aqui só foi visto no local.
  3. **[Thiago]** Teto de 30 para 1 no painel. O envio do passo 1 já ocupa a hora.
  4. Passados os 60 s, "Reenviar código" na A3: a mensagem do teto.
  5. Voltar à A1 e entrar de novo com o mesmo endereço: a mensagem do teto, e a A1 fica.
  6. A2 com outro endereço novo: a mensagem do teto, e a A2 fica.
  7. **[Thiago]** Teto de volta a 30, conferido na tela.

  Se o passo 2 não abrir a A3, ou se algum recusado mostrar "Aguarde um minuto", **parar**: o texto do remoto difere do local. Se o reenvio do passo 4 passar, o painel zerou a contagem ao mudar o teto. É um e-mail a mais, a A3 recebe um código, e os passos 5 e 6 seguem valendo.
- [ ] Limpeza: **[Thiago]** no editor SQL do painel, o SQL que o Claude preparar apaga o cadastro pendente do passo 1, pela ordem da T07. Depois, pelo MCP: `auth.users`, `pessoa` e `dispositivo_push` vazias.
- [ ] [T10](10-fechamento.md): a correção deixa o "Aberto" e entra nas decisões.

## Resultado

## Pronto quando

O teto e o intervalo de 60 s mostram mensagens diferentes. A A1 não abre a A3 no teto e continua abrindo no intervalo. O texto está nos documentos. O script local confere o `msg` dos 60 s. O remoto confirmou os dois casos com o APK release, e voltou a ficar sem usuário e com o teto em 30.

## Commit

Dois commits: `Documenta a mensagem do teto de e-mails` (rodada 1) e `Separa o teto de e-mails do intervalo entre envios` (rodada 2).
