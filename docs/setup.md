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
    _tests/           # testes de concorrência (Deno, conexões separadas)
  templates/          # e-mails do Supabase Auth
web/                  # página de convite no Cloudflare Pages (fatia 8)
docs/
specs/                # especificações do Spec Kit, uma por fatia
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
| `uv` e Spec Kit | `uv` atual; `specify-cli` | Especificação de cada fatia | `curl -LsSf https://astral.sh/uv/install.sh \| sh`; `uv tool install specify-cli` |
| Firebase CLI e FlutterFire CLI | Atual | Configurar o FCM (fatia 7) | Binário oficial do Firebase; `dart pub global activate flutterfire_cli` |

**Emuladores (AVD):** dois, ambos com imagem **Google Play** (exigida pelo login com Google e pelo push):
- API 29 (Android 10), a versão mínima (RNF01);
- API 36, a versão alvo (RNF02).

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

## 6. Login com Google

Usa o projeto `VoleiIn` do Google Cloud, já criado no v0.

- **Cliente web:** seu ID é o `GOOGLE_WEB_CLIENT_ID` do app e o `client_id` de `[auth.external.google]` no `config.toml`. O segredo dele é o `SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET`.
- **Clientes Android:** um por certificado que assina o app, todos com o pacote `br.com.voleiin`:
  - a chave de debug **de cada máquina** de desenvolvimento;
  - a chave de *upload* e a chave de assinatura da Google Play (no lançamento).

SHA-1 da chave de debug desta máquina:

```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android
```

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

- Senha de todos: `voleiin123`. Contas com e-mail já confirmado e termos aceitos na versão vigente.
- IDs fixos (UUIDs legíveis, como `00000000-0000-0000-0000-00000000000a` para a Ana), para que testes e anotações possam citá-los.
- O domínio `.test` é reservado e nunca entrega e-mail.

**Cenários:** o seed cresce a cada fatia, só com o que ela usa:

| Fatia | Acrescenta |
|-------|------------|
| 1 | As quatro contas, para o login técnico |
| 2 | Perfis completos: apelido, telefone visível e oculto, chave Pix |
| 3 | Um grupo com admin e membros, uma solicitação pendente |
| 4 | Jogos Aberto, Confirmado (com espera), em andamento e Cancelado; passagens canceladas no prazo e fora dele |
| 5 | Jogo Concluído com rateio, multas mantidas e isentadas, troca de recebedor |
| 6 | Valores Pendentes, Em análise, Pagos e Isentos; comprovantes nos três status |
| 7 | Notificações lidas e não lidas, preferências desligadas |

Jogos com horário relativo usam `now()` (por exemplo, `now() + interval '2 days'`), para o seed continuar válido em qualquer data.

## 9. Produção

**O agente nunca executa nada desta seção.** Tudo aqui é feito pelo responsável, à mão ou pelo pipeline (`trabalho-com-agente.md`, seção 6).

### 9.1 Acesso e pausa

- Numa máquina nova: `supabase login` e `supabase link --project-ref zmokpmovphikmobynssy`. O vínculo fica em `supabase/.temp/`, fora do Git.
- O plano grátis pausa o projeto após 1 semana sem uso. Pausado, o CLI responde `ProjectPausedError`. Para reativar, use o painel (sem custo, em poucos minutos). O que conta como "uso" será confirmado na fatia 1 (`requisitos-nao-funcionais.md`, seção 8).

### 9.2 Migração na produção, com ensaio

Não há backup (RNF09) nem banco remoto de teste. Por isso, **depois do lançamento**, cada migração é ensaiada antes com uma cópia dos dados reais. A cópia guardada serve de foto do banco antes da mudança. Não é backup contínuo.

1. **Baixar a cópia** para uma pasta fora do repositório:
   ```bash
   mkdir -p ~/voleiin-dumps && chmod 700 ~/voleiin-dumps
   supabase db dump --linked -f ~/voleiin-dumps/schema.sql
   supabase db dump --linked --data-only --use-copy -f ~/voleiin-dumps/data.sql
   ```
2. **Montar o banco local no estado da produção:** `supabase db reset --version <última migração aplicada na produção>` (a lista sai de `supabase migration list --linked`). Em seguida, carregar `data.sql` no banco local com `psql`.
3. **Aplicar a migração nova** no local (`supabase migration up`) e conferir: a migração termina sem erro, `supabase test db` passa e as contagens das tabelas afetadas batem com o esperado.
4. **Publicar** pelo workflow de deploy (`trabalho-com-agente.md`, seção 6), que pede a confirmação de que o ensaio foi feito.
5. **Guardar a cópia** até a próxima migração, que a substitui. A cópia tem telefone, chave Pix e e-mails: fica só nesta máquina, nunca no Git nem em nuvem.

Antes do lançamento, o ensaio é opcional, porque não há dados reais. **O procedimento é validado na fatia 1**, ainda com dados de teste. Os comandos acima são o ponto de partida: os esquemas incluídos no dump, em especial `auth`, devem ser conferidos e corrigidos aqui nessa validação.

### 9.3 Limpeza do projeto do v0 (fatia 1)

O projeto `VoleiIn` tem o banco do v0, em português, e precisa ficar como novo antes da primeira migração do projeto atual:

- reativar o projeto (está pausado desde 2026-11);
- apagar os esquemas, tabelas, funções, *jobs* do `pg_cron`, buckets do Storage e a Edge Function `enviar-push` do v0;
- apagar as contas de teste de `auth.users`;
- apagar o histórico de migrações do v0 (`supabase_migrations.schema_migrations`), para que `supabase migration list --linked` comece vazio;
- manter: região, SMTP do Resend, provedor Google e domínio de e-mail;
- conferir com `supabase migration list --linked` e com os advisors do painel.

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
| `permission denied` no Docker | Usuário fora do grupo `docker`, ou sessão não reaberta | `sudo usermod -aG docker $USER` e reabrir a sessão |
| Erro de geração (`*.freezed.dart` ou `*.g.dart` não encontrado) | `build_runner` não rodou | `dart run build_runner build --delete-conflicting-outputs` |
