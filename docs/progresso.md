# Progresso — VoleiIn

Registro do que já foi entregue, seguindo os dez passos de [stack.md](stack.md). Existe para que o estado do projeto seja conhecido em poucas linhas, sem reler o código.

O que entra aqui é o que **não se descobre lendo o código**: a decisão tomada durante a implementação e o motivo dela. Decisão de produto continua no [PRD](prd.md); aqui ficam só as de implementação.

## Estado

**Passo atual: 3 — Autenticação.**

| Passo | Estado |
| --- | --- |
| 1. Schema | feito |
| 2. Política de linha | feito |
| 3. Autenticação | a fazer |
| 4. Núcleo financeiro | a fazer |
| 5. App | a fazer |
| 6. Comprovante | a fazer |
| 7. Avisos | a fazer |
| 8. Rotinas | a fazer |
| 9. Convites | a fazer |
| 10. Distribuição | a fazer |

## Entregas

## Passo 1 — Schema · 2026-10-19

Os dez enums, as treze tabelas com as 27 chaves estrangeiras do modelo, as seis unicidades e os índices de leitura, mais um seed provisório do piloto. `supabase db reset` parte de banco vazio e `supabase/testes/schema.sql` passa com 61 asserções.

**Arquivos:** `supabase/migrations/` (`enums`, `tabelas`, `indices`), `supabase/seed.sql`, `supabase/testes/schema.sql`.

**Decisões de implementação:**
- Restrição de linha única vira `check` declarativo já no schema, para o banco recusar linha inválida venha de onde vier, inclusive do Studio. O que cruza tabelas fica nas funções do passo 4.
- A RN16 é `check` em `jogo`: `preco_por_vaga = (custo_total + vagas_total - 1) / vagas_total`, dentro de um `case` para não dividir por zero. Todo `update` de `custo_total` ou `vagas_total` precisa recalcular o preço no mesmo comando.
- `cobranca.confirmado_por` e `confirmado_em` andam juntos por `check`; a isenção manual também os preenche (RN07).
- `pessoa.id` não tem `default`: um `insert` sem id falha em vez de criar perfil sem credencial. É a única tabela fora da regra de `supabase/CLAUDE.md`.
- Enums nomeados `<entidade>_<campo>`. Unicidades são índices únicos, nomeados `<tabela>_<colunas>_unico`.
- Chaves estrangeiras sem `on delete cascade`: nada some em cascata, coerente com a preservação do histórico da RN27.
- Os únicos `default` de domínio são `local.verificado = false`, `membro_grupo.entrou_em` e `comprovante.enviado_em` com `now()`. Os `status` não têm padrão: as funções informam.
- `latitude` e `longitude` são `numeric` sem precisão fixa.
- As asserções rodam numa transação desfeita e exigem o nome da restrição que recusou, não só o código do erro. São a semente do script de cenários do passo 4.

**Aberto:**
- O seed é provisório (dois locais fictícios); trocar pelos locais, quadras, preços e horários reais do piloto quando existirem.
- `local.verificado` "sempre falso no MVP" (RN18) não tem `check`: ficou fora da lista do passo. Decidir se entra numa migração futura.
- Não há índice em `comprovante (cobranca_id)` nem nas chaves estrangeiras que ninguém consulta. Irrelevante no volume do piloto; reavaliar quando o passo 6 definir as consultas do comprovante.
- O usuário está no grupo `docker`, mas a sessão precisa ser reaberta para valer; até lá, os comandos rodam com `sg docker -c '…'`.

## Passo 2 — Política de linha · 2026-10-19

Política de linha ligada nas treze tabelas, conforme a matriz de `docs/stack.md`; o papel `anon` não alcança nada, e `authenticated` só escreve nas três exceções fora do rateio. A `listar_participantes` devolve a marca de débito vencido da RN26. `supabase/testes/rls.sql` passa com 69 asserções, e a `schema.sql` segue com 61.

**Arquivos:** `supabase/migrations/` (`rls`), `supabase/testes/rls.sql`.

**Decisões de implementação:**
- As auxiliares das políticas (`eh_membro`, `eh_admin`, `pode_ver_jogo`, `pode_ver_grupo`, `conhece`) são `security definer` num schema `privado`, fora da API: assim jogo e participação não se consultam em recursão, e nenhuma delas vira RPC.
- `privado.encerramento_previsto(inicio, duracao_minutos)` é a âncora da RN17; vencimento (RN07) e fim da janela de falta (RN04) são ela mais 24 horas. Os passos 4 e 8 devem usá-la, não recalcular.
- Além da política, os privilégios foram revogados: escrita sem privilégio falha com 42501, em vez de passar em silêncio sem tocar linha. As três escritas diretas têm grant por coluna — `pessoa` (nome, avatar_url, telefone, chave_pix), `notificacao` (lida_em), `dispositivo_push` (insert das colunas do app e delete).
- Privilégio padrão revogado: função ou tabela nova nasce sem acesso para `anon`, `authenticated` nem `public`. **Toda função RPC do passo 4 precisa de `grant execute ... to authenticated` explícito.**
- `listar_participantes` devolve `debito_vencido` vazio (`null`) para quem não tem papel, em vez de `false`, para não afirmar que a pessoa está em dia. Quem não vê o jogo recebe lista vazia, como na política.
- Os testes trocam de usuário como a API faz: papel `authenticated` e o id em `request.jwt.claims`, lido por `auth.uid()`.

**Aberto:**
- Token FCM já registrado por outra conta no mesmo aparelho: decidido depois do fechamento que o registro passa pela `registrar_dispositivo`, que transfere a linha (`docs/stack.md`, Política de linha). A migração `rls` ainda concede `insert` em `dispositivo_push`; a migração `avisos` do passo 7 revoga esse privilégio e a política `dispositivo_push_insert_titular`, e o `rls.sql` troca as asserções de insert direto pelas da função.
- Funções de grupo, de convite, `apagar_comprovante` e `registrar_dispositivo` entraram na lista de `docs/stack.md`, com passo definido: grupo no 4 (`rpc_grupo`), `apagar_comprovante` no 6, `registrar_dispositivo` no 7 (`avisos`), convites no 9 (`rpc_convite`).
- ~~Quem apaga os aparelhos na troca de e-mail (RNF07)~~ — resolvido na abertura do passo 3: um gatilho na mudança de `email` em `auth.users` apaga todo `dispositivo_push` do titular (`docs/stack.md`, Autenticação).

## Passo 3 — Autenticação · 2026-10-29

Projeto no Supabase remoto com o Resend como SMTP, entrada por e-mail e senha ou pela conta Google, e código de seis dígitos e cinco minutos na confirmação do cadastro, na redefinição de senha e na troca de e-mail. Os gatilhos de `auth.users` criam o perfil na confirmação e apagam os aparelhos de push na troca de e-mail e de senha. O app ganhou a base Flutter, as telas A1 a A4 e a de trocar e-mail. Validado ponta a ponta no local e no remoto, com o celular físico e com o roteiro da API. As suítes SQL passam com 61, 69 e 36 asserções, o `flutter test` com 41 testes e o `dart analyze` não acusa nada.

**Arquivos:** `supabase/migrations/` (`autenticacao`), `supabase/config.toml`, `supabase/templates/` (os cinco modelos de e-mail), `supabase/testes/autenticacao.sql` e `autenticacao_api.sh`; `app/` inteiro como base nova — `app/lib/core/` (`supabase.dart`, `google.dart`, `tema.dart`, `rotas.dart`), `app/lib/dados/auth_repositorio.dart`, `app/lib/features/auth/` — e `app/dart_defines.example.json`.

**Decisões de implementação:**
- `minSdk` 24, e não 23: o Flutter instalado já não dá suporte ao Android 6.
- As telas de acesso saíram com o design A1–A4, sobre a base escura do design system. O que o app muda ou completa em relação às imagens está em `docs/design/telas/01-acesso/implementacao.md`, não aqui.
- `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` e `GOOGLE_WEB_CLIENT_ID` entram por `--dart-define`, resolvidos na compilação, e nunca em arquivo versionado: o endereço muda com a rede e a chave com o Supabase local de cada máquina.
- O reenvio de código conta 60 s no app só para evitar um toque que o serviço recusaria; o limite é do servidor.
- Na redefinição, a senha nova é pedida junto com o código e antes de conferi-lo, porque a sessão nasce na conferência e a raiz do app troca a tela nesse momento.
- As escritas em `auth.users` nos testes SQL são feitas como `postgres`, que não pode assumir o papel do Auth; o caminho real pelo Auth foi conferido na T07.
- A entrada só por código (`signInWithOtp`) continua aberta no serviço, que não a desliga separada da senha. Fica sem modelo próprio e sem uso pelo app, e não é brecha: só deixa entrar quem controla o e-mail.
- Um gatilho só apaga os aparelhos de push, na mudança de `email` e na de `encrypted_password`, para o app não precisar cooperar.
- Comportamento observado na T07: o reenvio recusado nos 60 s da entrada com cadastro pendente é engolido, e o código anterior continua valendo; a sessão da redefinição nasce na conferência e fica de pé depois de `same_password`, então a A4 confere o código uma vez só e, nas tentativas seguintes, só grava a senha; o login pelo Google segue a identidade `google`, não o e-mail atual, e quem trocou o e-mail continua entrando com o Gmail antigo, na mesma conta; a troca de senha derruba as outras sessões sozinha, e o `signOut(others)` do app fica redundante, sem prejuízo.
- Cadastro refeito antes do código: o serviço ficava com a senha e o nome do primeiro pedido, o que entregava a conta da dona do e-mail a um impostor. A A3 aberta pela A2 grava, depois do código, o nome e a senha digitados (T13; `docs/prd.md`, RN21).
- O teto de 30 e-mails por hora e o intervalo de 60 s recusam com o mesmo `over_email_send_rate_limit`, e só o `msg` os separa. O app trata como intervalo o texto com "after N second" e como teto qualquer outro, com "Muitos códigos enviados agora. Tente de novo em até uma hora." e sem a A1 abrir a A3. O custo aceito é depender de um texto em inglês do serviço, que o roteiro da API confere a cada rodada (T09.8, T14).
- O Auth do remoto vem do `config.toml` por `supabase config push`. O SMTP e o teto de 30 por hora (`rate_limit.email_sent`) moram só no painel, porque o `config push` não os gerencia (T08.5, T08.6).
- `skip_nonce_check = true` também no remoto, porque o app não manda nonce. O `storage.vector` do diff do `config push` foi recusado: passaria de `false` a `true`, e o MVP não usa (T08.6).
- E-mail pelo Resend, com remetente `nao-responda@mail.voleiin.com.br` e domínio na região São Paulo (`sa-east-1`), a mesma do projeto. O DMARC do `voleiin.com.br` está em `p=reject`, com SPF e DKIM passando; falha de autenticação é recusa, não spam (T08.2, T08.7).
- O remoto (Auth v2.197.0, a mesma do local) bate com o local em todos os cenários da T07, com os mesmos códigos de erro. Responde `user_already_exists`, e não um usuário sem `identities`, e `validation_failed`, e não `email_address_invalid`; o código vence em 300 s. A tabela está no "Resultado" de `plan-tasks/passo-3/09-e2e-remoto.md`.
- `autenticacao_api.sh` roda no remoto com `EMAIL_CAIXA`, que manda todos os e-mails a uma caixa real com `+` e poupa a reputação do domínio novo; sem Mailpit, pede cada código no terminal e pula as conferências de aviso e de modelo (T09.2; comando em `supabase/CLAUDE.md`).
- O APK release pede `shared_preferences_android` 2.5.4 ou mais nova, porque o R8 quebrava a 2.5.0 na abertura: renomeava classes Kotlin chamadas por JNI, sem regra de manutenção. O release tem 54,0 MB (53.999.223 bytes), contra 107,5 MB do de depuração (T09.3).
- Quanto as bibliotecas acrescentaram ao APK release: o `google_sign_in` +412 KB (T04, de 52.722.572 para 53.144.602 bytes) e o `material_symbols_icons` com as fontes Montserrat e Bebas Neue +507 KB (T05, de 53.144.602 para 53.664.236 bytes).

<!-- Modelo de entrada, a copiar ao fechar um passo:

## Passo N — Nome · 2026-00-00

O que foi entregue, em duas ou três linhas.

**Arquivos:** os caminhos principais, não a lista completa.
**Decisões de implementação:** o que foi escolhido aqui e não está no PRD, com o motivo.
**Aberto:** o que ficou pendente e por quê.

Ao fechar uma tela: divergência em relação ao desenho vai para `docs/design/telas/<grupo>/implementacao.md`, não para cá.
-->
