# T09.6 — Celular: cadastro refeito e troca de e-mail

**Estado:** feito · **Depende de:** T09.5

## Objetivo

Com o endereço do **outro provedor**, a entrega fora do Gmail e dois caminhos que só foram conferidos no local: o cadastro refeito antes do código (cenário 6, corrigido na T13) e a troca de e-mail (13 e 16).

## O que já existe

- `autenticacao_api.sh --impostor <endereço>` cria o cadastro pendente com senha e nome "Impostor" e imprime o id. Sem `PSQL`, pula a conferência de banco; sem `MAILPIT_URL`, não pergunta nada, porque não lê o código.
- O Gmail 2 tem conta desde a T09.5, pelo Google: é o alvo do 16.

## O que falta

- [x] **6 refeito.** `CHAVE=<chave pública> AUTH_URL=https://zmokpmovphikmobynssy.supabase.co/auth/v1 MAILPIT_URL= PSQL= supabase/testes/autenticacao_api.sh --impostor <outro provedor>`. O código do impostor chega à caixa do Thiago, que não o usa.
- [x] **[Thiago]** Mais de 60 s depois, A2 com o mesmo endereço, outro nome e a senha descartável. Chega o código novo; A3; o início abre com "Olá, <nome da A2>", e chega "A senha da sua conta no VoleiIn foi trocada". Conferir por `curl`: a senha do impostor dá `invalid_credentials`, e a descartável entra. Pelo MCP: `pessoa.nome` é o da A2.
- [x] **13.** **[Thiago]** Na sessão, trocar o e-mail para o Gmail 2 com `+t09`. O código chega só no endereço novo; o aviso "O e-mail da sua conta no VoleiIn foi trocado" chega no outro provedor; o snackbar "E-mail trocado. Os outros aparelhos foram desconectados."; o app segue logado com o e-mail novo.
- [x] **16.** **[Thiago]** Trocar de novo, agora para o Gmail 2 sem sufixo: "Esse e-mail já pertence a outra conta.", a tela fica na etapa do e-mail, e nenhum e-mail chega.
- [x] Anotar a hora do último e-mail desta task: a T09.7 só começa uma hora depois.

## Resultado

Feito em 2026-10-28, de 00:13 a 00:43 UTC (21:13 a 21:43 de 27/10 em Brasília), no APK release da T09.3, com o Claude operando o celular pelo `adb`. Os três cenários batem com o local. Os e-mails do Outlook caíram **todos no Lixo Eletrônico**, com a autenticação inteira aprovada.

- **Endereço errado no começo.** O endereço do Outlook foi passado com um erro de digitação, e o impostor (00:13:40) e a A2 (00:14:46) foram para uma caixa que não existe. O Resend marcou os dois como *bounced* e pôs o endereço na lista de supressão. Ninguém recebeu nada, mas são duas devoluções na reputação do `voleiin.com.br`. Ficou no remoto um cadastro pendente nesse endereço (id `9abdf4bf…`, sem `pessoa`), que sai na T09.9. O cenário foi refeito do zero no endereço certo.
- **Conferências de banco pela API de dados**, com a sessão da própria conta (`GET /rest/v1/pessoa`), e não pelo MCP: a leitura do remoto pelo MCP foi barrada pelo modo automático do Claude Code. A política de linha deixa a pessoa ler a própria linha, e é o que o app mostra no "Olá".

| # | Observado | Contra o local | `error_code` |
| --- | --- | --- | --- |
| 6 refeito | `--impostor` às 00:24:32 (id `02a8df0a…`). A2 às 00:25:41, com "Thiago Silva" e a senha descartável; A3 com o código novo às 00:27:58 → "Olá, Thiago Silva". A senha do impostor dá 400, e a descartável entra. A conta é a do impostor (mesmo id), confirmada às 00:27:59, só com a identidade `email`. `pessoa.nome` = "Thiago Silva", `avatar_url` nulo. Nos metadados, `nome` continua "Impostor", como no local (T13) | igual | `invalid_credentials` |
| 13 | "Trocar e-mail" para o Gmail 2 com `+t09` às 00:41:52. O código chegou só no endereço novo; a confirmação às 00:42:20 → snackbar "E-mail trocado. Os outros aparelhos foram desconectados." e o início com o e-mail novo. O aviso chegou ao Outlook. A sessão aberta por `curl` às 00:28 perdeu a renovação, e o e-mail antigo não entra mais | igual | `refresh_token_not_found`, `invalid_credentials` |
| 16 | Troca para o Gmail 2 sem sufixo às 00:42:48: "Esse e-mail já pertence a outra conta.", e a tela fica na etapa do e-mail, com o endereço no campo. Nenhuma notificação nova do Gmail em 45 s, e nada novo no Outlook | igual | `email_exists` (pela mensagem do app; os logs do Auth não foram lidos) |

**E-mails**, todos com o remetente "VoleiIn" `<nao-responda@mail.voleiin.com.br>`:

| E-mail | Para | Pedido (UTC) | Chegada (Brasília) | Pasta |
| --- | --- | --- | --- | --- |
| "Confirme seu cadastro no VoleiIn" (impostor) | endereço errado | 00:13:40 | — | *bounced* |
| "Confirme seu cadastro no VoleiIn" (A2) | endereço errado | 00:14:46 | — | *bounced* |
| "Confirme seu cadastro no VoleiIn" (impostor) | Outlook | 00:24:32 | 21:24 | Lixo Eletrônico |
| "Confirme seu cadastro no VoleiIn" (A2) | Outlook | 00:25:41 | 21:25 | Lixo Eletrônico |
| "A senha da sua conta no VoleiIn foi trocada" | Outlook | 00:28:02 | 21:28 (00:28:03 UTC no cabeçalho, 1 s) | Lixo Eletrônico |
| "Confirme a troca de e-mail no VoleiIn" | Gmail 2 com `+t09` | 00:41:52 | 21:41 (00:41:57 UTC na notificação, 5 s) | entrada |
| "O e-mail da sua conta no VoleiIn foi trocado" | Outlook | 00:42:20 | 21:42 | Lixo Eletrônico |

- **Por que o Lixo Eletrônico.** O cabeçalho do aviso de senha trocada traz `spf=pass` (`rsend.mail.voleiin.com.br`), `dkim=pass` em `mail.voleiin.com.br` e em `amazonses.com`, `dmarc=pass` e `compauth=pass`, com `SCL: 5`, `BCL: 0` e `OFR:SpamFilterAuthJ`. A autenticação está certa, e o DNS confere com a T08: SPF e MX em `send.mail.`, DKIM em `resend._domainkey.mail.` e DMARC `p=reject` em `_dmarc.voleiin.com.br`. É o filtro de conteúdo e reputação da Microsoft, para um domínio de dois dias, com pouco volume e duas devoluções logo antes. Os mesmos modelos caem na caixa de entrada do Gmail (T09.4 e o 13). Pela regra do README, a execução parou, conferiu a configuração e seguiu com o Thiago. Nenhum e-mail foi marcado como "Não é lixo eletrônico", para não ensinar o filtro. Fica para a T09.9 levar à T10 como risco: quem usa Outlook pode não achar o código.
- **Celular em uso.** No meio da task, o Thiago estava no WhatsApp, e um toque do Claude caiu na lista dele, sem efeito. A operação parou até ele largar o aparelho.
- **Folha "Salvar senha"** de novo na A2, fechada com voltar.
- **Sessões que ficam no remoto:** a do app na conta do Outlook, agora com o e-mail do Gmail 2 com `+t09`, e a do `curl` da senha descartável, aberta depois da troca de senha. A troca de e-mail derrubou a do `curl`. A conta do 16 e as do Gmail 1 seguem como a T09.5 as deixou. Saem todas na T09.9.

**Último e-mail da task: 00:42:20 UTC.** A T09.7 começa a partir de 01:43 UTC de 2026-10-28 (22:43 de 27/10 em Brasília). Gastos na task: 7 envios, contra 5 previstos, por causa dos 2 *bounced*.

## Pronto quando

Depois do cadastro refeito valem o nome e a senha da A2, a troca de e-mail chega aos dois endereços certos, e o e-mail do outro provedor tem tempo, pasta e remetente anotados.

## Commit

`Registra o cadastro refeito e a troca de e-mail no remoto`
