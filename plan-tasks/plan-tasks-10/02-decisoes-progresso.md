# T10.2 — Entrada do passo 3: resumo, arquivos e decisões

**Estado:** a fazer · **Depende de:** T10.1

## Objetivo

Escrever em [`docs/progresso.md`](../../docs/progresso.md) a entrada "Passo 3 — Autenticação" até a seção **Decisões de implementação**, pelo modelo do fim do arquivo. O "Aberto" é a T10.3, e o estado do passo é a T10.4.

## O que já existe

- **O modelo**, no comentário do fim do `progresso.md`: título com a data, duas ou três linhas de resumo, **Arquivos**, **Decisões de implementação**, **Aberto**.
- **As duas entradas anteriores** (passos 1 e 2) como medida de tamanho e de tom: resumo curto, "Arquivos" com os caminhos principais e não a lista completa, e cada decisão numa linha com o motivo.
- **A regra do que entra:** o que não se descobre lendo o código. Decisão de produto fica no PRD; aqui, só as de implementação.
- **Os 17 itens de decisão já enumerados** na [T10](../passo-3/10-fechamento.md), com a fonte de cada um na tabela do [README](README.md#de-onde-sai-cada-bloco-da-entrada).
- **Os números**, medidos na T10.1.

## O que falta

- [ ] **Resumo**, em duas ou três linhas, cobrindo: projeto no Supabase remoto com Resend como SMTP; entrada por e-mail e senha ou conta Google; código de seis dígitos e cinco minutos na confirmação do cadastro, na redefinição e na troca de e-mail; os gatilhos de criação do perfil e de revogação dos aparelhos; as telas A1 a A4 e a de trocar e-mail; e os totais das suítes medidos na T10.1.
- [ ] **Arquivos**, só os caminhos principais:
  - `supabase/migrations/` (`autenticacao`), `supabase/config.toml`, `supabase/templates/` (os cinco modelos de e-mail);
  - `supabase/testes/autenticacao.sql` e `supabase/testes/autenticacao_api.sh`;
  - `app/` inteiro como base nova, citando `app/lib/core/` (`supabase.dart`, `google.dart`, `tema.dart`, `rotas.dart`), `app/lib/dados/auth_repositorio.dart` e `app/lib/features/auth/`;
  - `app/dart_defines.example.json`.
- [ ] **Decisões de implementação**, os 17 itens da T10, cada um numa linha com o motivo. Agrupar na ordem: plataforma e app → telas → configuração e segredos → comportamento observado → remoto e e-mail → tamanho do APK.
  - `minSdk` 24, porque o Flutter atual já não dá suporte ao Android 6;
  - as telas de acesso saíram com o design A1–A4, sobre a base escura do design system, com as divergências em `docs/design/telas/01-acesso/implementacao.md` (T05, T12) — **apontar, não repetir**;
  - `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` e `GOOGLE_WEB_CLIENT_ID` entram por `--dart-define`, nunca em arquivo versionado;
  - o reenvio conta 60 s no app só para evitar um toque que seria recusado; o limite é do servidor;
  - as escritas em `auth.users` nos testes SQL são feitas como `postgres`, e o caminho real pelo Auth foi conferido na T07;
  - a entrada só por código continua aberta no serviço, sem modelo próprio e sem uso pelo app;
  - um gatilho só revoga os aparelhos de push, na troca de e-mail e na de senha;
  - na redefinição, a senha nova é pedida junto com o código, porque a sessão nasce na conferência e a raiz troca a tela;
  - o comportamento dos cenários 6, 11 e 20 e a correção do cadastro refeito (T13), pelo "Anotar para a T10" de [`07-e2e-local.md`](../passo-3/07-e2e-local.md);
  - o Auth do remoto vem do `config.toml` por `supabase config push`; SMTP e teto de 30 por hora (`rate_limit.email_sent`) moram só no painel (T08.5, T08.6);
  - `skip_nonce_check = true` também no remoto, e `storage.vector` recusado no push, porque o MVP não usa (T08.6);
  - e-mail pelo Resend, remetente `nao-responda@mail.voleiin.com.br` em `sa-east-1`, DMARC do `voleiin.com.br` em `p=reject`, com SPF e DKIM passando (T08.2, T08.7);
  - o remoto (Auth v2.197.0, a mesma do local) bate com o local em todos os cenários, com os mesmos códigos de erro: `user_already_exists` em vez de usuário sem `identities`, `validation_failed` em vez de `email_address_invalid`, e código vencendo em 300 s (T09, "Resultado");
  - o APK release pede `shared_preferences_android` 2.5.4 ou mais nova, porque o R8 quebrava a 2.5.0 na abertura; 54,0 MB no release contra 107,5 MB no de depuração (T09.3);
  - `autenticacao_api.sh` roda no remoto com `EMAIL_CAIXA`, e sem Mailpit pede os códigos no terminal (T09.2);
  - o teto por hora e o intervalo de 60 s recusam com o mesmo `over_email_send_rate_limit`, e o app os separa pelo `msg`, com "Muitos códigos enviados agora. Tente de novo em até uma hora." e sem a A1 abrir a A3; o custo aceito é depender de um texto em inglês do serviço, conferido a cada rodada do roteiro (T09.8, T14);
  - quanto as bibliotecas acrescentaram ao APK: `google_sign_in` +412 KB (T04) e `material_symbols_icons` com Montserrat e Bebas Neue +507 KB (T05).
- [ ] Cada linha com fonte conferida. Linha sem fonte não entra: **parar e perguntar**.
- [ ] A entrada entra **depois** da do passo 2 e **antes** do comentário do modelo.
- [ ] O título leva a data do dia em que a entrada é escrita.

## Resultado

## Pronto quando

`docs/progresso.md` tem a entrada "Passo 3 — Autenticação" com resumo, "Arquivos" e as decisões de implementação, cada uma com motivo e fonte. O "Aberto" ainda não existe, e o estado do passo segue "a fazer".

## Commit

`Registra as decisões do passo 3 no progresso`
