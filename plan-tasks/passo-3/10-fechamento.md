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
  - e-mail pelo Resend, com remetente `nao-responda@mail.voleiin.com.br` na região `sa-east-1`; DMARC do `voleiin.com.br` em `p=reject`, com SPF e DKIM passando (T08.2, T08.7);
  - o remoto (Auth v2.197.0, a mesma do local) bate com o local em todos os cenários da T07, com os mesmos códigos de erro; responde `user_already_exists`, e não um usuário sem `identities`, e `validation_failed`, e não `email_address_invalid`; o código vence em 300 s. A tabela está no "Resultado" de [`09-e2e-remoto.md`](09-e2e-remoto.md);
  - o APK release pede `shared_preferences_android` 2.5.4 ou mais nova, porque o R8 quebrava a 2.5.0 na abertura; o release tem 54,0 MB (53.999.223 bytes), contra 107,5 MB do de depuração (T09.3);
  - `autenticacao_api.sh` roda no remoto com `EMAIL_CAIXA`, que manda todos os e-mails a uma caixa real com `+`, e sem Mailpit pede os códigos no terminal (T09.2, `supabase/CLAUDE.md`);
  - no remoto, o teto por hora devolve 429 `over_email_send_rate_limit`, o mesmo código do intervalo de 60 s, e só o `msg` os separa (T09.8).
- [ ] "Aberto" a registrar:
  - o domínio `voleiin.com.br` vence em 26/10/2027, com alerta no Google Agenda; vencido, derruba o login inteiro;
  - o `seed.sql` não foi ao remoto, que está sem locais nem quadras (T08.4);
  - o remoto chega ao passo 4 sem usuário, sem `pessoa` e sem `dispositivo_push`: as contas de teste da T08 e da T09 foram apagadas (T09.9);
  - **correção a fazer, decidida em 2026-10-28 (T09.8):** o teto de e-mails por hora chega ao app como "Aguarde um minuto antes de pedir outro código.", e a A1 o engole e abre a A3 esperando um código que não vem. O app passa a separar a recusa pelo `msg` do `over_email_send_rate_limit`: o dos 60 s ("…after N seconds") fica como hoje; qualquer outro é o teto, e a A2, a A3 e a A1 mostram "Muitos códigos enviados agora. Tente de novo em até uma hora.", sem a A1 abrir a A3. O texto entra nos documentos antes do código. Custo aceito: depende de um texto em inglês do Supabase Auth;
  - e-mails no Outlook caem no Lixo Eletrônico, com SPF, DKIM e DMARC aprovados (`SCL: 5`): é reputação de um domínio novo, não configuração (T09.6). Quem usa Outlook pode não achar o código. No Gmail, tudo chega na caixa de entrada em até 6 s;
  - no remoto não foram conferidos o `reauthentication_needed` da sessão envelhecida (12) nem as linhas de `dispositivo_push` (9 e 15), porque o script rodou sem `PSQL`; vieram ao remoto pela mesma migração e pelo mesmo `config.toml` conferidos na T07;
  - não se sabe se o teto de e-mails por hora conta por janela fixa ou por recarga contínua (T09.8);
  - cadastro pendente de impostor concluído pela redefinição de senha nasce com o nome do impostor; a senha vale a da dona, e o nome só se troca pela H2 (risco aceito em 2026-10-27; `docs/stack.md`, Riscos);
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
