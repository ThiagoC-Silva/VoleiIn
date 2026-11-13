# Guia de Ambiente

> Decisões de 09/11/2026. Base: `stacks.md` (seções 4, 5, 8 e 10), `requisitos-nao-funcionais.md` (seções 2, 3 e 8) e as lições do projeto anterior (VoleiIn v0).
> Objetivo: uma máquina limpa chega ao app rodando no emulador, falando com o Supabase local, em menos de 30 minutos.
> Alguns comandos só passam a funcionar depois da fatia 1, que cria `app/`, `supabase/config.toml` e as migrações.

## 1. Ambientes

São dois. Não há projeto remoto de homologação: o **Supabase local faz esse papel**.

| Ambiente | Supabase | App | Para quê |
|----------|----------|-----|----------|
| **Local** (desenvolvimento e homologação) | `supabase start`, na máquina | Build de debug no **emulador** | Escrever código, rodar os testes, conferir os fluxos de ponta a ponta |
| **Produção** | Projeto `VoleiIn`, ref `zmokpmovphikmobynssy`, `sa-east-1` | Google Play | Uso real da turma |

- **Um app só.** O pacote é sempre `br.com.voleiin`. O ambiente é escolhido no build, por `--dart-define-from-file`, e não há *flavors*. Por isso o build de teste e o de produção não ficam instalados juntos: a homologação é testada no emulador, e o celular de verdade fica com o app da loja.
- **Até o lançamento**, a produção só tem contas de teste e pode receber experimentos (Resend, Google, App Links, push real). **Depois do lançamento**, toda migração passa pelo ensaio da seção 9.2.
- O projeto `VoleiIn` veio do v0. Ele é limpo na fatia 1 (seção 9.3).

## 2. Organização do repositório

```
app/                  # app Flutter (pacote br.com.voleiin)
  env/                # variáveis por ambiente (só o example.json vai para o Git)
supabase/
  config.toml
  migrations/         # schema versionado
  seed.sql            # dados de desenvolvimento (seção 8)
  tests/database/     # testes pgTAP (*.test.sql)
  functions/          # Edge Functions em Deno
    _shared/          # código comum
    _tests/           # testes contra o Supabase de pé: Storage (fatia 2) e concorrência (Deno)
  templates/          # e-mails do Supabase Auth
web/                  # página de convite no Cloudflare Pages (fatia 8)
docs/
specs/                # especificações do Spec Kit, uma por fatia
scripts/              # emulador e testes de integração com limite de memória (seção 3.1)
.github/workflows/    # CI e deploy
```

## 3. Pré-requisitos

| Ferramenta | Versão | Para quê | Instalação |
|------------|--------|----------|------------|
| Git e GitHub CLI (`gh`) | Atual | Repositório e PRs | Gerenciador de pacotes do sistema |
| Flutter (com Dart) | Estável, 3.47 ou superior (Dart 3.13) | App | `snap install flutter --classic` |
| Android Studio | Atual | SDK do Android, emuladores e `keytool` | Site oficial |
| Docker | Atual | Supabase local | Gerenciador de pacotes; o usuário precisa estar no grupo `docker` |
| Supabase CLI | Estável mais recente (não usar versões `-next`) | Banco local, migrações, testes pgTAP, Edge Functions | Pacote `.deb` das *releases* do GitHub |
| Deno | 2.x | Testes das Edge Functions e de concorrência | `curl -fsSL https://deno.land/install.sh \| sh` |
| `uv` e Spec Kit | `uv` atual; `specify-cli` 1.4 ou superior | Especificação de cada fatia | `curl -LsSf https://astral.sh/uv/install.sh \| sh`; `uv tool install specify-cli --from git+https://github.com/github/spec-kit.git` |
| Firebase CLI e FlutterFire CLI | Atual | Configurar o FCM (fatia 7) | Binário oficial do Firebase; `dart pub global activate flutterfire_cli` |

**Emuladores (AVD):** dois, ambos com imagem **Google Play** (exigida pelo login com Google e pelo push):
- `voleiin_api29`: API 29 (Android 10), a versão mínima (RNF01);
- `voleiin_api36`: API 36, a versão alvo (RNF02).

Criação pela linha de comando, com o `sdkmanager` e o `avdmanager` do `cmdline-tools`:

```bash
sdkmanager "system-images;android-29;google_apis_playstore;x86_64" "system-images;android-36;google_apis_playstore;x86_64"
avdmanager create avd -n voleiin_api29 -k "system-images;android-29;google_apis_playstore;x86_64" -d pixel_4
avdmanager create avd -n voleiin_api36 -k "system-images;android-36;google_apis_playstore;x86_64" -d pixel_7
```

Os testes de integração rodam com um emulador aberto e o Supabase local de pé, sempre pelos scripts da seção 3.1:

```bash
scripts/emulator.sh 36            # ou 29; espera o boot terminar
scripts/integration-test.sh       # todos; ou um arquivo: scripts/integration-test.sh integration_test/account_flow_test.dart
```

### 3.1 Memória

**Máquina mínima:** 16 GB de RAM. Recomendado ter 8 GB de swap (abaixo).

Em 13/11/2026, numa máquina de 16 GB com 2 GB de swap, a sessão gráfica caiu inteira no meio dos testes de integração. O `systemd-oomd` (ligado por padrão no Ubuntu) encerra o grupo de processos que mais disputa memória quando a pressão passa de 50% por 20 segundos, e escolheu o GNOME Shell. Rodavam juntos o emulador, o build do Gradle (com os 8 GB de heap do modelo do Flutter), os testes de unidade, o Supabase local e os navegadores. Nenhum deles sozinho derruba a máquina; a soma, sim.

O padrão do projeto, já no repositório e válido em qualquer máquina:

| Item | Configuração | Onde | Memória |
|------|--------------|------|---------|
| Build do Gradle | heap de 3 GB, metaspace de 1 GB, Kotlin dentro do Gradle (sem segundo daemon), daemon sai após 10 min parado | `app/android/gradle.properties` | até ~4 GB, só durante o build |
| Emulador | 2 GB de RAM, GPU por software, sem snapshot; um por vez | `scripts/emulator.sh` | ~3 GB |
| Supabase local | `analytics` desligado (leva junto o `vector`) | `supabase/config.toml` | ~1,1 GB |
| Testes de integração | só começam com 4,5 GB livres e sem testes de unidade rodando | `scripts/integration-test.sh` | — |

**A regra:** com o emulador aberto, **um comando pesado por vez**. Não rode `flutter test`, `supabase test db`, `deno test` ou outro build enquanto o teste de integração compila ou roda. Antes de abrir o emulador, feche abas e navegadores que não estiver usando. Os scripts conferem a memória disponível e param com uma mensagem quando falta folga. `VOLEIIN_SKIP_MEMORY_CHECK=1` pula a conferência.

**Swap (uma vez por máquina, com `sudo`).** Com 2 GB de swap, a memória chega ao limite sem margem. Com 8 GB, o sistema tira da RAM o que está parado (abas, Studio) antes de o oomd agir:

```bash
swapon --show                      # tamanho atual
sudo swapoff /swapfile
sudo fallocate -l 8G /swapfile
sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile
```

O `/swapfile` já costuma estar no `/etc/fstab` do Ubuntu; se não estiver, acrescente `/swapfile none swap sw 0 0`. Não desligue o `systemd-oomd`: sem ele, a máquina tende a congelar em vez de fechar a sessão.

**Caminho com acento.** O projeto pode ficar em "Área de trabalho", mas o `flutter analyze` quebra com `FormatException` quando o caminho tem acento. **Use sempre `dart analyze`**, que faz a mesma análise e funciona em qualquer caminho. O CI também usa `dart analyze`.

## 4. Primeira execução

```bash
# 1. Repositório
git clone <url-do-repositório> && cd VoleiIn

# 2. Segredos locais (seção 5): copiar os exemplos e preencher
cp supabase/.env.example supabase/.env
cp supabase/functions/.env.example supabase/functions/.env
cp app/env/example.json app/env/local.json

# 3. Supabase local (Docker rodando)
supabase start          # mostra a URL e a chave pública (publishable)
supabase db reset       # recria o banco com as migrações e o seed

# 4. App
cd app
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # freezed e json_serializable
flutter run --dart-define-from-file=env/local.json         # com um emulador aberto
```

Para entrar no app, use um usuário do seed (seção 8), por exemplo `ana@voleiin.test`.

**Endereço do Supabase no emulador.** Dentro do emulador, `127.0.0.1` é o próprio emulador. O computador é visto como `10.0.2.2`. Por isso o `env/local.json` usa `SUPABASE_URL=http://10.0.2.2:54321`, que não muda com a rede.

**E-mails no local.** O Supabase local não envia e-mail de verdade: todos caem no Mailpit, em `http://127.0.0.1:54324`.

## 5. Variáveis e segredos

Nenhum segredo vai para o Git. Os arquivos locais abaixo estão no `.gitignore`, e cada um tem um `example` versionado, com os nomes e sem os valores.

### 5.1 App (`--dart-define-from-file`)

| Variável | Local (`app/env/local.json`) | Produção (`app/env/prod.json`) | É segredo? |
|----------|------------------------------|--------------------------------|------------|
| `SUPABASE_URL` | `http://10.0.2.2:54321` | `https://zmokpmovphikmobynssy.supabase.co` | Não |
| `SUPABASE_PUBLISHABLE_KEY` | Chave `publishable` de `supabase status` | `supabase projects api-keys --project-ref zmokpmovphikmobynssy`, a de tipo `publishable` | Não |
| `GOOGLE_WEB_CLIENT_ID` | ID do cliente web do Google (seção 6) | O mesmo | Não |

O app lê com `String.fromEnvironment` e para logo na abertura com uma mensagem clara se alguma faltar. **No app só entram identificadores públicos.** A chave de serviço (`service_role`) nunca entra.

### 5.2 Servidor

| Segredo | Onde fica no local | Onde fica na produção | Quem usa |
|---------|--------------------|-----------------------|----------|
| `SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET` | `supabase/.env`, lido pelo `config.toml` com `env()` | Painel do Supabase, Auth → Google | Login com Google |
| `ANTHROPIC_API_KEY` | `supabase/functions/.env` | `supabase secrets set` | `process-receipt` (fatia 6) |
| `RECEIPT_MODEL` | `supabase/functions/.env` | `supabase secrets set` | Modelo da Claude API, trocável sem novo deploy (`stacks.md`, 6.2) |
| `FCM_SERVICE_ACCOUNT` | `supabase/functions/.env` | `supabase secrets set` | `send-push` (fatia 7) |
| SMTP do Resend | Não se aplica (Mailpit) | Painel, Auth → SMTP: host `smtp.resend.com`, usuário `resend`, senha = chave da API do Resend | E-mails de autenticação |

O SMTP e o limite de e-mails por hora só são configurados pelo painel: o `supabase config push` não os leva.

### 5.3 GitHub (*secrets* do repositório)

| Segredo | Uso |
|---------|-----|
| `SUPABASE_ACCESS_TOKEN`, `SUPABASE_DB_PASSWORD` | Deploy de migrações e de Edge Functions na produção |
| `PROD_SUPABASE_PUBLISHABLE_KEY`, `GOOGLE_WEB_CLIENT_ID` | Gerar o `env/prod.json` no build de release |
| `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` | Assinar o Android App Bundle (lançamento) |

O ref do projeto (`zmokpmovphikmobynssy`) e a URL não são segredo e ficam no workflow.

## 6. Supabase Auth e login com Google

### 6.1 E-mail, código e senha (fatia 2)

Os três e-mails de conta levam um código de 6 dígitos (ADR 0017). No local, as opções ficam no `supabase/config.toml`. Na produção, as mesmas opções são ajustadas no painel (Authentication → Sign In / Providers, Email Templates e Rate Limits), porque o SMTP e os limites não vão pelo `supabase config push` (seção 5.2).

| Opção (`config.toml`) | Valor | Por quê |
|-----------------------|-------|---------|
| `[auth.email] enable_confirmations` | `true` | Sem confirmação não há sessão (RF02) |
| `[auth.email] double_confirm_changes` | `false` | Na troca de e-mail, o código vai só ao endereço novo (RF106) |
| `[auth.email] otp_length` e `otp_expiry` | `6` e `3600` | Código de 6 dígitos, válido por 1 hora |
| `[auth] minimum_password_length` | `8` | Decisão de 12/11/2026 (`docs/ui/telas.md`, seção 5) |
| `[auth] password_requirements` | `""` | Sem exigir número ou símbolo |
| `[auth.email.template.confirmation]`, `.recovery`, `.email_change` | `subject` e `content_path = "./supabase/templates/<arquivo>.html"` | Textos e assuntos no `docs/copy.md`, seção 6.9 |
| `[auth] site_url` | Fica como está | Sem link nos e-mails, o endereço não é usado |

- **No local,** os e-mails caem no Mailpit (seção 4), que também é lido pelos testes de integração (`testes-referencia.md`, seção 10.4).
- **Limite de envio:** o padrão local é `email_sent = 2` por hora, o que trava o "Reenviar código" e os testes de integração. O `config.toml` sobe para `30` no local. Na produção, com o SMTP do Resend, o limite fica no painel, em 30 por hora.
- **Modelos:** cada arquivo citado em `content_path` precisa existir antes do `supabase start`. Sem ele, o Docker cria uma pasta com o nome do arquivo (seção 11).

### 6.2 Login com Google

Usa o projeto `VoleiIn` do Google Cloud, já criado no v0.

- **Cliente web:** seu ID é o `GOOGLE_WEB_CLIENT_ID` do app e o `client_id` de `[auth.external.google]` no `config.toml`. O segredo dele é o `SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET`.
- **Clientes Android:** um por certificado que assina o app, todos com o pacote `br.com.voleiin`:
  - a chave de debug **de cada máquina** de desenvolvimento;
  - a chave de *upload* e a chave de assinatura da Google Play (no lançamento).

SHA-1 da chave de debug desta máquina:

```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android
```

**No `config.toml`,** além do `client_id` e do `secret`, o `[auth.external.google]` leva `skip_nonce_check = true`: o app troca o ID token por sessão (`signInWithIdToken`) sem enviar *nonce*. O `supabase start` exige a variável do segredo mesmo sem ninguém entrar com Google; no CI ela recebe um valor qualquer (research R11 de `specs/001-conta-e-perfil`).

Sem o SHA-1 cadastrado, o seletor de contas abre, a conta é escolhida e o login falha. O `adb logcat` mostra `UNREGISTERED_ON_API_CONSOLE`. Depois de uma falha, o Google Play Services guarda o veredito por alguns minutos: espere uns dez minutos antes de concluir que o cadastro não pegou.

## 7. Firebase (fatia 7)

Um projeto Firebase, `voleiin`, com um app Android `br.com.voleiin`. `flutterfire configure` gera `app/lib/firebase_options.dart` e `app/android/app/google-services.json`. Os dois vão para o Git: identificam o projeto e não são segredo, como a chave pública do Supabase. A credencial que envia push é a `FCM_SERVICE_ACCOUNT`, que fica só no servidor.

## 8. Seeds de desenvolvimento

`supabase/seed.sql` roda a cada `supabase db reset`, **só no local**. Ele insere direto nas tabelas, como `postgres`, sem passar pelas funções, para montar cenários que levariam muitos passos pelo app. Ele nunca roda na produção.

**Personagens**, os mesmos de `testes-referencia.md` e de `regras-negocio.md`:

| Pessoa | E-mail | Papel nos cenários |
|--------|--------|---------------------|
| Ana | `ana@voleiin.test` | Recebedora, com chave Pix, admin do grupo |
| Bruno | `bruno@voleiin.test` | Membro, participante |
| Carla | `carla@voleiin.test` | Membro, participante, às vezes na espera |
| Diego | `diego@voleiin.test` | Sem grupo, para os testes de "sem contexto" (RN107) |

**Perfis da fatia 2:** Ana com telefone visível e chave CPF; Bruno com o apelido `Brunão`, telefone oculto e chave e-mail; Carla com o apelido `Carlinha`, sem telefone e com chave aleatória; Diego só com o nome. Os fluxos L09 a L11 devolvem esses valores no fim (`testes-referencia.md`, 10.4).

- Senha de todos: `voleiin123`. Contas com e-mail já confirmado e termos aceitos na versão vigente, que vem de `current_terms_versions()` (`contratos-api.md`, seção 9). O seed grava a mesma versão (`1.0`); quando uma migração trocar a versão, o seed muda junto.
- IDs fixos (UUIDs legíveis, como `00000000-0000-0000-0000-00000000000a` para a Ana), para que testes e anotações possam citá-los.
- O domínio `.test` é reservado e nunca entrega e-mail.

**Cenários:** o seed cresce a cada fatia, só com o que ela usa:

| Fatia | Acrescenta |
|-------|------------|
| 1 | As quatro contas, para o login técnico |
| 2 | Perfis completos: apelido, telefone visível e oculto, chave Pix. O aceite dos termos na versão `1.0`, a mesma de `current_terms_versions()` |
| 3 | Um grupo com admin e membros, uma solicitação pendente |
| 4 | Jogos Aberto, Confirmado (com espera), em andamento e Cancelado; passagens canceladas no prazo e fora dele |
| 5 | Jogo Concluído com rateio, multas mantidas e isentadas, troca de recebedor |
| 6 | Valores Pendentes, Em análise, Pagos e Isentos; comprovantes nos três status |
| 7 | Notificações lidas e não lidas, preferências desligadas |

Jogos com horário relativo usam `now()` (por exemplo, `now() + interval '2 days'`), para o seed continuar válido em qualquer data.

## 9. Produção

**O agente pode executar esta seção** (decisão de 13/11/2026, `trabalho-com-agente.md`, seções 7 e 8). O que pede senha ou login interativo fica com o responsável, com `! <comando>`. Antes de cada `supabase db push`, o agente roda o ensaio da seção 9.2.

### 9.1 Acesso e pausa

- Numa máquina nova: `supabase login` e `supabase link --project-ref zmokpmovphikmobynssy`. O vínculo fica em `supabase/.temp/`, fora do Git.
- O plano grátis pausa o projeto após 1 semana sem uso. Pausado, o CLI responde `ProjectPausedError`. Para reativar, use o painel (sem custo, em poucos minutos, por até 90 dias depois da pausa). O que conta como "uso" é a **atividade de consultas no banco** vinda de usuários (chamadas da API ou do app): algumas por dia na semana bastam. Jobs do `pg_cron` não contam, porque rodam dentro do próprio projeto. A Supabase avisa por e-mail uma semana antes de pausar (confirmado em 12/11/2026, `requisitos-nao-funcionais.md`, seção 8).

### 9.2 Migração na produção, com ensaio

Não há backup (RNF09) nem banco remoto de teste. Por isso, **depois do lançamento**, cada migração é ensaiada antes com uma cópia dos dados reais. A cópia guardada serve de foto do banco antes da mudança. Não é backup contínuo.

1. **Baixar a cópia** para uma pasta fora do repositório:
   ```bash
   mkdir -p ~/voleiin-dumps && chmod 700 ~/voleiin-dumps
   supabase db dump --linked -f ~/voleiin-dumps/schema.sql
   supabase db dump --linked --data-only --use-copy -s public,auth -f ~/voleiin-dumps/data.sql
   ```
   Os dados saem só de `public` e `auth`. O `storage` fica de fora: as linhas de `storage.buckets` já nascem da migração (o `COPY` delas dá chave duplicada), as outras tabelas do `storage` pertencem ao `supabase_storage_admin` (o `COPY` dá `permission denied`), e os arquivos em si não vêm no dump.
2. **Montar o banco local no estado da produção**, sem o seed:
   ```bash
   supabase migration list --linked          # última migração aplicada na produção
   supabase db reset --version <essa versão> --no-seed
   docker cp ~/voleiin-dumps/data.sql supabase_db_VoleiIn:/tmp/data.sql
   docker exec supabase_db_VoleiIn psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q -f /tmp/data.sql
   docker exec supabase_db_VoleiIn rm /tmp/data.sql
   ```
   O `psql` roda dentro do container do banco, e não precisa estar instalado na máquina. O dump começa com `session_replication_role = replica`, então as *triggers* (como a que cria o perfil a partir de `auth.users`) não disparam na carga.
3. **Aplicar a migração nova** no local (`supabase migration up`) e conferir: a migração termina sem erro, `supabase test db` passa e as contagens das tabelas afetadas batem com o esperado.
4. **Publicar** pelo workflow de deploy (`trabalho-com-agente.md`, seção 6), que pede a confirmação de que o ensaio foi feito. Esse workflow ainda não existe (decisão de 11/11/2026: ele entra numa fatia próxima do lançamento). Até lá, a publicação é à mão, pelo agente ou pelo responsável, na raiz do repositório:
   ```bash
   supabase login                                        # uma vez por máquina
   supabase link --project-ref zmokpmovphikmobynssy      # pede a senha do banco
   supabase migration list --linked                      # confere o que já foi aplicado
   supabase db push                                      # aplica as migrações novas
   ```
5. **Guardar a cópia** até a próxima migração, que a substitui. A cópia tem telefone, chave Pix e e-mails: fica só nesta máquina, nunca no Git nem em nuvem.

Antes do lançamento, o ensaio é opcional, porque não há dados reais. **O procedimento foi validado na fatia 1, em 12/11/2026**, com a produção recém-migrada e ainda vazia: os comandos acima já trazem as correções que a validação mostrou (dados só de `public` e `auth`, `--no-seed` e o `psql` do container). As colunas de `auth` da produção e do Supabase local bateram, porque o `COPY` de cada tabela cita as colunas e passou. Os testes pgTAP criam os personagens do seed que usam, então passam também no banco do ensaio, que não tem seed.

### 9.3 Limpeza do projeto do v0 (fatia 1)

**Feita em 12/11/2026**, pelo agente, com autorização expressa do responsável para esta tarefa. O projeto tinha só o esquema do v0, sem dados: nenhuma conta, nenhum bucket ou arquivo, sem `pg_cron` e sem Edge Functions. Foram apagados os esquemas `privado` e `public` (recriado vazio, com os privilégios padrão) e as 14 linhas do histórico de migrações. Em seguida, `supabase db push` aplicou as 13 migrações da fatia 1. Conferência: 20 tabelas, todas com RLS, buckets `avatars` e `receipts`, e o advisor de segurança só com o aviso esperado de RLS sem política (`rls-matriz.md`). O registro abaixo fica como referência do que foi pedido.

O projeto `VoleiIn` tem o banco do v0, em português, e precisa ficar como novo antes da primeira migração do projeto atual:

- reativar o projeto (está pausado desde 2026-11);
- apagar os esquemas, tabelas, funções, *jobs* do `pg_cron`, buckets do Storage e a Edge Function `enviar-push` do v0;
- apagar as contas de teste de `auth.users`;
- apagar o histórico de migrações do v0 (`supabase_migrations.schema_migrations`), para que `supabase migration list --linked` comece vazio;
- manter: região, SMTP do Resend, provedor Google e domínio de e-mail;
- conferir com `supabase migration list --linked` e com os advisors do painel.

### 9.4 Migrações da fatia 2 (13/11/2026)

**Feita em 13/11/2026**, pelo agente, já com o acesso à produção liberado (`trabalho-com-agente.md`, seção 8). A produção tinha as 13 migrações da fatia 1 e nenhuma conta.

- Ensaio da seção 9.2: cópia em `~/voleiin-dumps`, banco local montado na versão `20261111121200` sem seed, as 6 migrações novas aplicadas sem erro e os 145 testes pgTAP verdes. Nenhuma tabela sem RLS.
- `supabase db push --dry-run` listou as mesmas 6, sem seed nem roles, e o `supabase db push` as aplicou: `20261113120000` a `20261113120400` e `20261113162203` (CNPJ alfanumérico).
- Conferência: `list_migrations` com as 19 migrações. Advisors só com avisos INFO: RLS sem política nas 17 tabelas das fatias seguintes (eram 20; `profiles`, `profile_private` e `terms_acceptances` ganharam política) e, em desempenho, chaves estrangeiras sem índice e índices sem uso, num banco ainda vazio.
- **Auth da produção (13/11/2026):** a produção ainda tinha os modelos de e-mail do v0, sem o código no assunto, e `otp_expiry = 300`. O `supabase config push` levou os três modelos de `supabase/templates/` e `otp_expiry = 3600` (seção 6.1). Ficaram como estavam na produção, de propósito: `max_frequency = 1m` (o `1s` do `config.toml` é para os testes locais) e `secure_password_change = true` (os fluxos do app entram de novo antes de trocar a senha). Para levar só isso, o push rodou de uma cópia temporária do `config.toml` com esses dois valores iguais aos da produção. O SMTP do Resend e o Google, mantidos do v0, continuaram.
- **M03 e M04** conferidos com o responsável, no celular, com o build da produção: os três e-mails chegaram pelo Resend, de `nao-responda@mail.voleiin.com.br`, com o código no assunto; cadastro por e-mail, Google e vinculação funcionaram. Ficou na produção uma conta de teste do responsável, com as identidades `email` e `google`.

## 10. Domínio, e-mail e convites

| Item | Valor | Observação |
|------|-------|------------|
| Domínio | `voleiin.com.br` | O registro vence em **26/10/2027**. Vencido, o e-mail para e o login por e-mail cai junto |
| E-mail | Remetente `nao-responda@mail.voleiin.com.br`, pelo Resend | DMARC do domínio em `p=reject` |
| Convites | `convite.voleiin.com.br`, no Cloudflare Pages (fatia 8) | `/.well-known/assetlinks.json` com o SHA-256 da chave de debug de cada máquina e da chave de assinatura da Google Play |

## 11. Problemas comuns

| Sintoma | Causa | O que fazer |
|---------|-------|-------------|
| `flutter analyze` termina com `FormatException: Unexpected end of input` | Acento no caminho do projeto | Use `dart analyze` |
| Login com Google volta com erro, e o `logcat` mostra `UNREGISTERED_ON_API_CONSOLE` | SHA-1 da máquina não cadastrado | Seção 6; espere uns dez minutos depois de cadastrar |
| O app no emulador não alcança o Supabase | `SUPABASE_URL` com `127.0.0.1` ou `localhost` | Use `http://10.0.2.2:54321` |
| `supabase start` falha por porta ocupada | Outro projeto Supabase rodando | `supabase stop --all` |
| Aparece uma **pasta** com nome `.html` em `supabase/templates/` | O Docker cria uma pasta quando o arquivo citado no `config.toml` não existe | Apague a pasta e crie o arquivo de template |
| `ProjectPausedError` | Produção pausada por falta de uso | Reative pelo painel (seção 9.1) |
| O emulador fecha sozinho durante o build do Gradle, e o log tem `process_memory.cc` e `short read` | Falta de memória com GPU do computador | Abra o emulador por `scripts/emulator.sh`, que usa `-gpu swiftshader_indirect` (seção 3.1) |
| A sessão gráfica cai e volta à tela de login, sem reiniciar; `journalctl -u systemd-oomd` mostra `Killed ... org.gnome.Shell ... due to memory pressure` | Memória esgotada por emulador, build e testes ao mesmo tempo | Siga a seção 3.1: scripts, um comando pesado por vez, swap de 8 GB |
| `flutter test integration_test` instala o app, o app abre no emulador e nada mais sai no terminal | O *runner* do teste perde a conexão com o aparelho logo depois do boot (visto na imagem Google Play de API 36, com a memória da máquina cheia) | Encerre o `flutter test` e o emulador, abra o emulador de novo, espere uns 20 s depois do boot e rode com `timeout 900` na frente |
| `adb: more than one device/emulator` | Celular ligado por USB ou Wi-Fi além do emulador | Desligue o celular do `adb`; os scripts escolhem o primeiro emulador. Fora deles, passe `-d emulator-5554` ao `flutter test` e `-s emulator-5554` ao `adb` |
| `permission denied` no Docker | Usuário fora do grupo `docker`, ou sessão não reaberta | `sudo usermod -aG docker $USER` e reabrir a sessão |
| Erro de geração (`*.freezed.dart` ou `*.g.dart` não encontrado) | `build_runner` não rodou | `dart run build_runner build --delete-conflicting-outputs` |
