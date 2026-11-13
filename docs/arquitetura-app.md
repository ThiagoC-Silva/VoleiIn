# Guia de Arquitetura

> Decisões de 09/11/2026. Base: `stacks.md` (seções 3, 4 e 11), `contratos-api.md` (seções 1, 2 e 9), `modelo-dados.md` e `requisitos-nao-funcionais.md`.
> Padrões concretos para copiar. Se um caso não couber aqui, pare e pergunte antes de inventar um padrão novo. Um padrão novo entra neste documento antes de se repetir no código.

## 1. Princípio

**O app exibe; o servidor decide.** Rateio, multa, status, prazo e permissão são calculados no banco (CLAUDE.md, "Nunca faça"). O app:

- **lê** tabelas por `select`, limitado pelo RLS, e assina o Realtime;
- **muda estado** só por `supabase.rpc` (funções SQL) e `supabase.functions.invoke` (Edge Functions). As únicas escritas diretas são as da seção 9 do `contratos-api.md`;
- **mostra** o resultado e converte códigos de erro em texto.

Se uma tela parecer precisar de um `insert` ou `update` direto numa tabela de regra, falta uma função no servidor. Pare e pergunte.

## 2. Estrutura do app

```
app/lib/
  main.dart                 # lê o ambiente, inicia Supabase, roda o app
  app.dart                  # MaterialApp.router, tema, localização
  core/
    env.dart                # variáveis de --dart-define (setup.md, seção 5.1)
    supabase.dart           # provider do SupabaseClient
    router/                 # go_router: rotas, redirects, nomes de rota
    theme/app_theme.dart    # docs/ui/design-system.md, seção 9
    errors/                 # AppException, ErrorCode, conversão e texto
    format/                 # dinheiro, data e hora (seção 8); CPF, CNPJ, telefone,
                            # tipo de imagem e UUID (fatia 2)
    submit_controller.dart  # ActionController, base das ações (seção 5)
    realtime.dart           # ajudante de assinatura (seção 6)
  l10n/app_pt.arb           # todos os textos da interface
  shared/widgets/           # componentes do design system
  features/
    auth/                   # RF01 a RF13, RF101, RF105 a RF108
    groups/                 # RF14 a RF25, RF102, RF103
    games/                  # RF26 a RF45
    attendance/             # RF46 a RF55
    penalties/              # RF56 a RF65
    splits/                 # RF66 a RF76
    payments/               # RF77 a RF87
    notifications/          # RF88 a RF100, RF104
      data/                 # repositórios: única camada que fala com o Supabase
      domain/               # modelos freezed e enums, sem regra de negócio
      presentation/         # telas, widgets da feature e providers
app/test/                   # espelha lib/
app/integration_test/       # fluxos de ponta a ponta no emulador
```

**Fluxo de dependência:** `presentation` → `data` → `domain`. `domain` não importa nada de Flutter nem do Supabase. Uma feature pode ler o `domain` de outra, mas não o `data` nem o `presentation`. O que é comum sobe para `core/` ou `shared/`.

**Sem camada de casos de uso.** A regra está no servidor, então o repositório chama a função e o provider expõe o resultado. Uma camada a mais só repassaria chamadas.

## 3. Pacotes

| Pacote | Uso |
|--------|-----|
| `supabase_flutter` | Banco, Auth, Storage, Edge Functions e Realtime |
| `flutter_riverpod` (3.x) | Estado e injeção de dependência |
| `go_router` | Rotas e deep links |
| `freezed`, `freezed_annotation`, `json_serializable`, `json_annotation`, `build_runner` | Modelos imutáveis e JSON |
| `flutter_localizations`, `intl` | Textos (`flutter gen-l10n`) e formatação de datas |
| `timezone` | Conversão para `America/Fortaleza` (RN01) |
| `material_symbols_icons` | Ícones (`design-system.md`, seção 6) |
| `google_sign_in` | Login com Google |
| `image_picker`, `file_picker`, `share_plus`, `app_links`, `firebase_core`, `firebase_messaging`, `flutter_local_notifications` | Entram nas fatias que os usam (`stacks.md`, 3.1) |
| `http` | Já vem com `supabase_flutter`; declarada porque a conversão de erros cita `ClientException` (seção 7) |
| `mocktail` (dev) | Dublês nos testes |
| `flutter_lints` (dev) | Regras do `dart analyze` |

**Pacote novo** precisa de motivo, de custo zero e de entrada nesta tabela antes de ir para o `pubspec.yaml`. Fora da lista: `riverpod_generator` (ver seção 5), `google_fonts` (fontes vão como asset), `shared_preferences` (o app não guarda dados no aparelho, RNF07), `connectivity_plus` (a falta de conexão é detectada pelo erro da chamada, seção 7).

## 4. Modelos (`domain`)

- Um modelo por linha de tabela ou retorno de função, com `freezed` e `json_serializable`.
- Nomes de campo em `camelCase` no Dart. O JSON segue o `snake_case` do banco por configuração global, em `app/build.yaml`:
  ```yaml
  targets:
    $default:
      builders:
        json_serializable:
          options:
            field_rename: snake
  ```
- Enums do banco viram enums Dart com o valor do banco em `@JsonValue('under_review')`. Valor desconhecido quebra a leitura de propósito (`unknownEnumValue` não é usado), porque um enum novo exige atualização do app.
- **Dinheiro:** `int` com sufixo `Cents` (`amountCents`). Nunca `double`, nem em conta intermediária.
- **Instantes:** `DateTime` em UTC, como vêm do banco. A conversão para `America/Fortaleza` acontece só na exibição (seção 8).
- O modelo não calcula regra. `estimatedShareCents` (RN24), por exemplo, é exibição e mora em `core/format`, não no modelo.

## 5. Riverpod

Riverpod 3, com providers escritos à mão, sem `riverpod_generator`. A geração de código fica restrita a `freezed` e `json_serializable`, e o agente lê o provider tal como ele roda.

| Necessidade | Provider | Exemplo |
|-------------|----------|---------|
| Cliente ou repositório | `Provider` | `profileRepositoryProvider` |
| Dados de uma tela | `FutureProvider.autoDispose` ou `.family` | `gameDetailProvider(gameId)` |
| Dados com Realtime | `AsyncNotifierProvider.autoDispose.family`, que assina no `build` (seção 6) | `attendanceProvider(gameId)` |
| Ação do usuário (formulário, botão) | `AsyncNotifierProvider.autoDispose<ActionController, void>`, um por tela, com o estado da submissão | `_saveProvider` em `profile_edit_screen.dart` |
| Estado de tela em memória (e-mail do código pendente) | `NotifierProvider` | `pendingEmailProvider` |
| Sessão | `StreamProvider` sobre `onAuthStateChange` | `authStateProvider` |

Regras:
- `ActionController` (`core/submit_controller.dart`) tem só `run(ação)`, que devolve `true` se deu certo e deixa o erro em `state.error`. A tela decide o que fazer com o erro: no campo (código errado, senha atual errada) ou em `SnackBar`.
- Depois de uma mutação, a tela ou o controller chama `ref.invalidate` nos providers de leitura afetados. O app não monta a resposta à mão: ela vem do servidor na próxima leitura.
- Tela de dados usa `.autoDispose`: ao sair da tela, a assinatura e o dado somem (RNF07, nada guardado para consulta offline).
- Widgets leem com `ref.watch` e chamam ações com `ref.read(...notifier)`. Nunca `ref.read` no `build`.
- Nos testes, repositórios são trocados com `ProviderScope(overrides: [...])`.

## 6. Realtime

**O Realtime é só um sinal para recarregar.** Ao receber qualquer mudança, o provider recarrega a leitura completa. O app nunca aplica o evento sobre o estado local: assim a tela mostra sempre o que o servidor e o RLS devolvem, e não há fusão de estado para errar.

```dart
class AttendanceNotifier extends AsyncNotifier<Attendance> {
  AttendanceNotifier(this.gameId);
  final String gameId;

  @override
  Future<Attendance> build() async {
    final channel = ref.read(supabaseProvider)
        .channel('attendance:$gameId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'game_participants',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'game_id', value: gameId),
          callback: (_) => ref.invalidateSelf(),
        )
        .subscribe();
    ref.onDispose(channel.unsubscribe);
    return ref.read(attendanceRepositoryProvider).fetch(gameId);
  }
}

final attendanceProvider = AsyncNotifierProvider.autoDispose
    .family<AttendanceNotifier, Attendance, String>(AttendanceNotifier.new);
```

As tabelas que entram na publicação `supabase_realtime` são as do `stacks.md` (seção 4.1): `games`, `game_participants`, `game_waitlist` e `notifications`. A inclusão é feita por migração, na fatia que usa cada uma.

## 7. Erros

Tudo o que sai do Supabase passa por uma conversão única, em `core/errors/`, e vira `AppException(ErrorCode code)`.

| Origem | Como chega | Vira |
|--------|------------|------|
| Função SQL | `PostgrestException` com `code == 'P0001'` e o código em `message` | `ErrorCode` correspondente |
| Edge Function | `FunctionException` com `{ "error": { "code": ... } }` no corpo | `ErrorCode` correspondente |
| Trigger de escrita direta | `PostgrestException` `P0001` (por exemplo, `PIX_KEY_IN_USE`) | `ErrorCode` correspondente |
| Supabase Auth | `AuthException` | Código do app pelas tabelas do `docs/copy.md` (seções 5.5 e 6.8) |
| Storage | `StorageException` | `photoTooLarge` (HTTP 413) ou `photoInvalidType` (`invalid_mime_type`), pelo `docs/copy.md` (seção 6.8) |
| Login com Google | Retorno nulo do `google_sign_in` (seletor fechado) ou exceção dele | Nulo não é erro. A exceção vira `authGoogleFailed` |
| Sem rede | `SocketException`, `ClientException`, `TimeoutException` | `ErrorCode.noConnection` (RNF07) |
| Qualquer outra coisa, ou código desconhecido | — | `ErrorCode.internalError` |

- `guard(chamada)` (`core/errors/error_mapper.dart`) executa a chamada e converte qualquer exceção em `AppException` por esta tabela. Todo método de repositório passa por ele.
- `ErrorCode` é um enum com os códigos do `contratos-api.md` (seção 2) que o app já usa, mais `noConnection` e os de autenticação. Ele cresce a cada fatia, junto com os textos do `docs/copy.md`. Ao fim da fatia 8, tem todos os códigos do catálogo.
- O texto vem de uma função com `switch` exaustivo sobre `ErrorCode`, que lê o `app_pt.arb` (`errorGameFull`, `errorNotFound` etc.). Código novo sem texto não compila.
- A tela não lê `message` do Postgres nem mostra texto técnico.
- Erro ao carregar a tela vira o estado de erro ou de sem conexão (`design-system.md`, 7.16). Erro de uma ação vira `SnackBar`, e a tela continua como estava.

## 8. Dinheiro, data e hora

- **Dinheiro:** `formatCents(int cents)` devolve `R$ 1.234,56`, com conta inteira (`cents ~/ 100` e `cents % 100`), sem `double` (RN04, RNF06). Na entrada, o campo de dinheiro converte o texto digitado direto para centavos inteiros.
- **Data e hora:** `formatDate` (`dd/mm/aaaa`), `formatTime` (`HH:mm`, 24 horas) e `formatShortDate` (`qui, 22/10`, formato no `docs/copy.md`) convertem de UTC para `America/Fortaleza` com o pacote `timezone`, iniciado no `main`. A hora do aparelho e o fuso dele não entram na conta.
- **Envio de instantes:** o app converte o que a pessoa escolheu (em `America/Fortaleza`) para UTC e envia em ISO 8601 (`contratos-api.md`, seção 1).
- **Relógio do aparelho:** pode **esconder** um botão que já não faz sentido (por exemplo, "Entrar na lista" depois do início) ou mostrar um texto relativo ("começa em 2 h"). Nunca **libera** uma ação nem decide um resultado: quem decide é o servidor, e a recusa dele (`GAME_STARTED` etc.) é tratada como erro de ação (RN02).

## 9. Navegação

- `go_router`, com as rotas em `core/router/`. Cada rota tem um nome constante. Navegação sempre por nome (`context.goNamed`), nunca por caminho escrito no widget.
- As raízes da navegação inferior usam `StatefulShellRoute.indexedStack`. Os destinos estão em `docs/ui/telas.md`.
- **Redirecionamentos**, nesta ordem: sem sessão → login, salvo nas rotas de acesso (`/signup`, `/confirm-email`, `/forgot-password`); com sessão numa rota de acesso → `/games`; termos não aceitos na versão vigente (RF105) → `/terms`; caso contrário, segue. E-mail não confirmado não tem sessão, porque a confirmação é por código (ADR 0017): a `/confirm-email` é aberta pelo cadastro e pelo erro `email_not_confirmed` do login, e não por redirecionamento (`docs/ui/telas.md`, seção 3.1).
- **Estado de acesso em memória:** o e-mail do código pendente (cadastro, recuperação e troca de e-mail) e o resultado da conferência dos termos ficam em providers, nunca no aparelho nem na rota. A conferência roda ao abrir o app com sessão e depois de cada login, e é refeita depois do aceite.
- **Deep links** (fatia 8): `/g/:code` e `/j/:code`. Sem sessão, o convite fica num provider em memória (não no aparelho, RNF07) e é retomado depois do login.
- Parâmetro de rota é sempre um ID ou um código. Os dados são relidos do servidor ao abrir a tela, nunca passados como objeto entre telas.

## 10. Textos

- Toda string de interface fica em `app/lib/l10n/app_pt.arb`, gerada com `flutter gen-l10n` (`generate: true` no `pubspec.yaml` e `l10n.yaml` com `pt` como único idioma).
- A chave é em inglês e `camelCase`, prefixada pela feature: `gamesEmptyTitle`, `paymentsCopyPixKey`. Erros usam `error` + o código em `camelCase`.
- Textos com valor usam placeholders do ARB (`{amount}`), preenchidos com o texto já formatado pela seção 8.
- O texto vem do catálogo de textos, `docs/copy.md`, que cresce a cada fatia.

## 11. Testes

| Tipo | Onde | O que cobre | Regras |
|------|------|-------------|--------|
| Unitário | `app/test/**` | Formatação, conversão de erros, modelos (JSON de ida e volta), controllers com repositório falso | Sem rede, sem Supabase |
| Widget | `app/test/**` | Cada tela nos estados carregando, vazio, erro, sem conexão e com dados; textos vindos do ARB; fonte em 150% sem `overflow` | Repositórios trocados por `mocktail` via `ProviderScope.overrides` |
| Integração | `app/integration_test/` | Os fluxos de "Pronto quando" de cada fatia | No emulador, contra o Supabase local com o seed |

- O arquivo de teste espelha o caminho do arquivo testado: `lib/core/format/money.dart` → `test/core/format/money_test.dart`.
- **Ajudantes** (`test/helpers/`): `TestApp` monta uma tela solta; `pumpRouterApp` monta um `go_router` em que as telas do teste são reais e as outras rotas mostram `stub:<nome>`, num celular de 412 × 915 dp, e devolve o `ProviderContainer`; `tapVisible` rola até o widget antes de tocar; `fakes.dart` tem os dublês dos repositórios e os dados de exemplo (`ownProfile`, versões dos termos).
- O teste do roteador (`test/core/router/app_router_test.dart`) usa o `routerProvider` real, com os repositórios trocados.
- O resultado esperado vem dos documentos (`testes-referencia.md`, RN, RF), nunca do que o código devolve.

## 12. Exemplo: a feature de conta (fatia 2)

A fatia 2 trocou o exemplo escrito antes do código pela feature real, em `features/auth/`. Os padrões a copiar:

| Camada | Arquivo | Padrão |
|--------|---------|--------|
| `domain` | `profile.dart`, `terms.dart`, `pix_key_type.dart` | Modelos `freezed` com JSON em `snake_case`. `TermsStatus.compare` só compara versões; a regra de qual versão vale está no servidor (`current_terms_versions()`) |
| `data` | `profile_repository.dart` | Leitura e escrita direta permitida (`contratos-api.md`, seção 9), cada método dentro de `guard` |
| `data` | `auth_repository.dart`, `google_auth_client.dart`, `photo_picker.dart` | Serviços de fora (Google, câmera) atrás de uma interface, trocada por dublê nos testes |
| `presentation` | `profile_providers.dart` | `ownProfileProvider` (`FutureProvider.autoDispose`), relido ao voltar de cada edição |
| `presentation` | `profile_edit_screen.dart` | Tela que lê com `switch` sobre o `AsyncValue` (carregando, erro, dados) e grava com um `ActionController` próprio |
| Roteador | `core/router/app_router.dart` | Redirecionamentos da seção 9, inclusive a conferência dos termos, que o roteador escuta com `ref.listen` |

Os testes de cada tela estão em `test/features/auth/presentation/`, com os IDs de `testes-referencia.md` (seção 10.4) no nome.

## 13. Anti-padrões

| Não faça | Por quê |
|----------|---------|
| Calcular rateio, multa, status ou "pode/não pode" no app | O servidor decide; duas implementações divergem, e um centavo errado quebra a validação do comprovante (RN04, RN88) |
| `double` para dinheiro, inclusive em conta intermediária | Erro de arredondamento |
| `DateTime.now()` para liberar uma ação | Relógio do aparelho não é confiável (RN02) |
| `insert`/`update` em tabela de regra | Só as funções validam papel, tempo e estado (`contratos-api.md`, seção 9) |
| Aplicar o evento do Realtime sobre o estado local | Diverge do servidor e do RLS; recarregue (seção 6) |
| Passar um objeto inteiro entre telas | Fica velho; passe o ID e releia |
| String de interface no código | Tudo vem do ARB (seção 10) |
| Cor ou hex no widget | Tudo vem do tema (`design-system.md`, seção 9) |
| Mostrar `e.toString()` ou a mensagem do Postgres | Texto técnico para o usuário; use o `ErrorCode` |
| Guardar dados no aparelho (cache, `shared_preferences`, banco local) | Sem uso offline (RNF07) |
| Altura fixa em componente com texto | Quebra com a fonte em 150% (RNF05) |
| `Icons.*` do Material | Os ícones são os do `material_symbols_icons` |

## 14. Convenções do servidor

### 14.1 Migrações

- Sempre criadas com `supabase migration new <nome>`. O nome é em inglês e `snake_case` e diz o que muda (`create_enums`, `games_rls`, `create_join_game`).
- **Nunca edite uma migração que já foi aplicada na produção.** Corrija com uma migração nova. A produção não roda de novo um arquivo que já rodou, e editar faz o local e a produção divergirem em silêncio.
- Toda migração passa por `supabase db reset`, que recria o banco do zero e aplica todas em ordem.

### 14.2 Esquemas e permissões

- Tabelas, enums e funções chamadas pelo app ficam em `public`.
- **Funções auxiliares e internas ficam no esquema `private`**, que a API não expõe: `private.is_group_member`, `private.is_group_admin`, `private.is_game_admin`, `private.can_view_game`, `private.shares_context`, `private.emit_notification` e as tarefas agendadas. Em `public`, toda função vira uma chamada da API: um `shares_context(a, b)` público deixaria qualquer usuário descobrir quem se conhece.
- **Privilégios padrão revogados** na primeira migração: tabela ou função nova nasce sem acesso para `anon` e `authenticated`. Cada fatia concede o que precisa:
  - `grant select` nas tabelas que o app lê;
  - `grant insert`/`update` **por coluna** nas escritas diretas da seção 9 do `contratos-api.md`;
  - `grant execute ... to authenticated` em cada função pública do app.
- RLS ativado em toda tabela, e o teste da fatia 1 falha se alguma ficar sem (CLAUDE.md, "Nunca faça").
- Como as Edge Functions chamam as funções internas (por exemplo, `emit_notification` a partir de `process-receipt`) fica decidido na fatia 6, sem expor a função ao app.

### 14.3 Formato de uma função do app

```sql
create or replace function public.leave_game(p_game_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_game public.games;
begin
  -- Ordem das validações: contratos-api.md, seção 1.
  if v_uid is null then
    raise exception using errcode = 'P0001', message = 'NOT_AUTHENTICATED';
  end if;

  select * into v_game from public.games where id = p_game_id for update;
  if not found or not private.can_view_game(p_game_id, v_uid) then
    raise exception using errcode = 'P0001', message = 'NOT_FOUND';
  end if;

  -- papel, estado, tempo (now() do servidor), dados de entrada...

  return jsonb_build_object('status', 'cancelled');
end;
$$;

revoke execute on function public.leave_game(uuid) from public, anon;
grant execute on function public.leave_game(uuid) to authenticated;
```

- Nomes qualificados (`public.games`, `private.can_view_game`), porque o `search_path` é vazio.
- Violação de índice único em corrida é capturada (`exception when unique_violation`) e convertida no código de negócio (`contratos-api.md`, seção 1).

### 14.4 Testes do servidor

| Tipo | Onde | Comando |
|------|------|---------|
| pgTAP (schema, RLS, funções) | `supabase/tests/database/<assunto>.test.sql` | `supabase test db` |
| Edge Functions | `supabase/functions/<nome>/*_test.ts` | `deno test` |
| Concorrência | `supabase/functions/_tests/concurrency/*_test.ts`, com conexões separadas ao banco local | `deno test --allow-net --allow-env` |

- Cada teste pgTAP roda numa transação desfeita no fim, sem deixar dados.
- Um teste pgTAP não depende do seed: os personagens que ele usa (Ana, Bruno, Carla e Diego, com os IDs fixos de `setup.md`, seção 8) são inseridos no começo da transação, com `on conflict do nothing`. Assim o teste roda no banco com seed e no banco do ensaio de migração, montado com a cópia da produção (`setup.md`, 9.2).
- O teste de RLS simula o usuário como a API faz: `set local role authenticated` e `set local request.jwt.claims` com o `sub` do usuário.
- Os IDs dos cenários de `testes-referencia.md` (T01, I04...) aparecem no nome de cada asserção, para ligar a falha à regra.

### 14.5 Edge Functions

- Uma pasta por função em `supabase/functions/<nome>/index.ts`, com código comum em `supabase/functions/_shared/`.
- Verificação do JWT de quem chama em toda função de app. Funções internas exigem a chave de serviço (`stacks.md`, 13.4).
- Respostas de erro no formato do `contratos-api.md` (seção 1).
- Logs estruturados em JSON (`event`, IDs, `result`), sem dados pessoais (`stacks.md`, seção 9).
- Serviços externos (Claude API, FCM) passam por uma interface em `_shared/`, trocada por um dublê nos testes.
