# T10 — Fechamento do passo 3

**Estado:** a fazer · **Depende de:** T09

## Objetivo

Registrar o passo 3 em `docs/progresso.md` e liberar o passo 4.

## O que falta

- [ ] `docs/progresso.md`:
  - "Passo atual" → 4; na tabela, passo 3 → feito;
  - entrada "Passo 3 — Autenticação", pelo modelo do fim do arquivo.
- [ ] Decisões de implementação a registrar (o que não está no PRD):
  - `minSdk` 24, porque o Flutter atual já não dá suporte ao Android 6;
  - as telas de acesso saíram com o design A1–A4 (`docs/design/`), sobre a base escura do design system; as divergências estão em `docs/design/telas/01-acesso/implementacao.md` (T05, T12);
  - a chave do Supabase e o cliente web do Google entram no app por `--dart-define` (`SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `GOOGLE_WEB_CLIENT_ID`), nunca em arquivo versionado;
  - o reenvio de código conta 60 s no app só para evitar um toque que seria recusado; o limite é do servidor;
  - as escritas em `auth.users` nos testes SQL são feitas como `postgres`; o caminho real pelo Auth foi conferido na T07;
  - a entrada só por código continua aberta no serviço, sem modelo próprio e sem uso pelo app;
  - um gatilho só revoga os aparelhos de push, na troca de e-mail e na de senha;
  - na redefinição, a senha nova é pedida junto com o código, porque a sessão nasce na conferência e a raiz troca a tela;
  - quanto o `google_sign_in` acrescentou ao APK (T04: +412 KB), e o `material_symbols_icons` com as fontes Montserrat e Bebas Neue (T05: +507 KB, de 53.144.602 para 53.664.236 bytes);
  - o comportamento observado nos cenários 6, 11 e 20 da T07, e a correção do cadastro refeito (T13): o que levar está em "Anotar para a T10" de [`07-e2e-local.md`](07-e2e-local.md);
  - o Auth do remoto vem do `config.toml` pelo `supabase config push`; o SMTP e o teto de 30 e-mails por hora (`rate_limit.email_sent`) moram só no painel, porque o `config push` não os gerencia (T08.5, T08.6);
  - `skip_nonce_check = true` também no remoto, e o `storage.vector` recusado no push, porque o MVP não usa (T08.6);
  - e-mail pelo Resend, com remetente `nao-responda@mail.voleiin.com.br` na região `sa-east-1`; DMARC do `voleiin.com.br` em `p=reject`, com SPF e DKIM passando (T08.2, T08.7).
- [ ] "Aberto" a registrar:
  - o domínio `voleiin.com.br` vence em 26/10/2027, com alerta no Google Agenda; vencido, derruba o login inteiro;
  - o `seed.sql` não foi ao remoto, que está sem locais nem quadras (T08.4);
  - uma conta de teste (Gmail secundário com `+t087`) fica no remoto, confirmada e com `pessoa` (T08.7);
  - a base clara do design system e a escolha de aparência ficam para o grupo H, que tem o botão de trocar; a troca de e-mail usa as casas do código, mas o resto da H3 não foi aplicado;
  - `flutter analyze` quebra com o caminho "Área de trabalho"; contorno pelo `dart analyze` (link simbólico não resolve);
  - tela de consentimento do Google em teste: só as usuárias de teste entram pelo Google até o passo 10, que publica a tela com página inicial e Política de Privacidade no GitHub Pages;
  - chave própria de assinatura do APK distribuído, com o SHA-1 dela no cliente Android do Google (passo 10); até lá, o release assina com a chave de debug de quem o gera;
  - `inicio_tela.dart` é provisória; sair ainda não apaga o aparelho de push (passo 7).
- [ ] Atualizar o estado de todas as tasks em `plan-tasks/passo-3/README.md`.
- [ ] Atualizar a memória do projeto: passo 3 fechado e `plan-tasks/` versionado por passo.

## Pronto quando

- `docs/progresso.md` mostra o passo 3 como feito, com data.
- `git status` limpo.

## Commit

`Fecha o passo 3 — Autenticação`
