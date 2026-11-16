import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState;
import 'package:voleiin/app.dart';
import 'package:voleiin/core/clock.dart';
import 'package:voleiin/core/date_time_picker.dart';
import 'package:voleiin/core/errors/error_code.dart';
import 'package:voleiin/core/share.dart';
import 'package:voleiin/core/router/app_router.dart';
import 'package:voleiin/features/auth/data/auth_repository.dart';
import 'package:voleiin/core/photo_picker.dart';
import 'package:voleiin/features/auth/data/profile_repository.dart';
import 'package:voleiin/features/auth/data/terms_repository.dart';
import 'package:voleiin/features/auth/domain/legal_document.dart';
import 'package:voleiin/features/auth/domain/own_profile.dart';
import 'package:voleiin/features/auth/domain/pix_key.dart';
import 'package:voleiin/features/auth/domain/profile.dart';
import 'package:voleiin/features/auth/domain/profile_private.dart';
import 'package:voleiin/features/auth/domain/terms.dart';
import 'package:voleiin/features/games/data/games_repository.dart';
import 'package:voleiin/features/games/domain/game_models.dart';
import 'package:voleiin/features/groups/data/groups_repository.dart';
import 'package:voleiin/features/groups/domain/group_models.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockProfileRepository extends Mock implements ProfileRepository {}

class MockTermsRepository extends Mock implements TermsRepository {}

class MockPhotoPicker extends Mock implements PhotoPicker {}

class MockGroupsRepository extends Mock implements GroupsRepository {}

class MockSharer extends Mock implements Sharer {}

class MockGamesRepository extends Mock implements GamesRepository {}

class FakeGameInput extends Fake implements GameInput {}

/// Seletores nativos de data e hora trocados por respostas em fila: cada
/// toque num campo de data ou de hora consome a próxima.
class FakeDateTimePicker implements DateTimePicker {
  final dates = <DateTime?>[];
  final times = <TimeOfDay?>[];

  @override
  Future<DateTime?> pickDate(BuildContext context, {DateTime? initial}) async =>
      dates.isEmpty ? null : dates.removeAt(0);

  @override
  Future<TimeOfDay?> pickTime(
    BuildContext context, {
    TimeOfDay? initial,
  }) async => times.isEmpty ? null : times.removeAt(0);
}

// IDs do seed (docs/setup.md, seção 8).
const anaId = '00000000-0000-0000-0000-00000000000a';
const brunoId = '00000000-0000-0000-0000-00000000000b';
const carlaId = '00000000-0000-0000-0000-00000000000c';
const diegoId = '00000000-0000-0000-0000-00000000000d';

const termsOfUse10 = TermsVersion(
  document: LegalDocument.termsOfUse,
  version: '1.0',
);
const privacyPolicy10 = TermsVersion(
  document: LegalDocument.privacyPolicy,
  version: '1.0',
);

/// Monta o app inteiro, com o roteador real e os repositórios trocados por
/// dublês (docs/arquitetura-app.md, seção 11). Cada teste diz só o que muda.
class TestHarness {
  TestHarness() {
    registerFallbackValue(PhotoSource.gallery);
    registerFallbackValue(<TermsVersion>[]);
    registerFallbackValue(PixKeyType.cpf);
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(GroupRole.member);
    registerFallbackValue(FakeGameInput());
    registerFallbackValue(() {});

    when(() => auth.onAuthStateChange)
        .thenAnswer((_) => const Stream<AuthState>.empty());
    when(() => auth.signOut()).thenAnswer((_) async {});
    signedOut();
    termsAccepted();
    ownProfile();
    myGroups(const []);
    when(() => groups.avatarUrl(any())).thenAnswer(
      (_) async => 'http://127.0.0.1:54321/storage/v1/object/sign/avatars/g',
    );
    when(() => sharer.shareText(any())).thenAnswer((_) async {});

    myGames(const []);
    when(() => games.hasPixKey()).thenAnswer((_) async => true);
    when(() => games.fetchMyGroupOptions()).thenAnswer((_) async => const []);
    when(() => games.fetchGroupGames(any())).thenAnswer((_) async => const []);
    when(() => games.avatarUrl(any())).thenAnswer(
      (_) async => 'http://127.0.0.1:54321/storage/v1/object/sign/avatars/p',
    );
    when(() => games.watchGame(any(), any())).thenAnswer((invocation) {
      final gameId = invocation.positionalArguments[0] as String;
      _realtime[gameId] = invocation.positionalArguments[1] as void Function();
      return () => _realtime.remove(gameId);
    });
  }

  final auth = MockAuthRepository();
  final profiles = MockProfileRepository();
  final terms = MockTermsRepository();
  final picker = MockPhotoPicker();
  final groups = MockGroupsRepository();
  final sharer = MockSharer();
  final games = MockGamesRepository();
  final pickers = FakeDateTimePicker();

  /// O relógio do aparelho, só para mostrar (docs/arquitetura-app.md, seção
  /// 8). Segunda, 16/11/2026, 12:00 em Fortaleza, antes de todos os jogos dos
  /// cenários.
  DateTime now = DateTime.utc(2026, 11, 16, 15);

  /// Quem assinou o Realtime de cada jogo (research R11).
  final _realtime = <String, void Function()>{};

  late final ProviderContainer container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      profileRepositoryProvider.overrideWithValue(profiles),
      termsRepositoryProvider.overrideWithValue(terms),
      photoPickerProvider.overrideWithValue(picker),
      groupsRepositoryProvider.overrideWithValue(groups),
      sharerProvider.overrideWithValue(sharer),
      gamesRepositoryProvider.overrideWithValue(games),
      dateTimePickerProvider.overrideWithValue(pickers),
      clockProvider.overrideWithValue(() => now),
    ],
    // Sem repetição automática: quem tenta de novo é a pessoa.
    retry: (_, _) => null,
  );

  GoRouter get router => container.read(routerProvider);

  /// Caminho da tela que está na frente. O `currentConfiguration.uri` não
  /// muda no `push` (go_router 18): o `state` é o da rota do topo.
  String get location => router.state.uri.path;

  void signedOut() {
    when(() => auth.hasSession).thenReturn(false);
    when(() => auth.currentUserId).thenReturn(null);
    when(() => auth.currentEmail).thenReturn(null);
    when(() => auth.hasEmailAccess).thenReturn(false);
  }

  void signedIn({
    String userId = anaId,
    String email = 'ana@exemplo.com',
    bool hasEmailAccess = true,
  }) {
    when(() => auth.hasSession).thenReturn(true);
    when(() => auth.currentUserId).thenReturn(userId);
    when(() => auth.currentEmail).thenReturn(email);
    when(() => auth.hasEmailAccess).thenReturn(hasEmailAccess);
  }

  /// Versão vigente dos dois documentos e a versão que a pessoa aceitou.
  /// `accepted: null` é quem nunca aceitou.
  void termsAccepted({String current = '1.0', String? accepted = '1.0'}) {
    when(() => terms.currentVersions()).thenAnswer(
      (_) async => [
        TermsVersion(document: LegalDocument.termsOfUse, version: current),
        TermsVersion(document: LegalDocument.privacyPolicy, version: current),
      ],
    );
    when(() => terms.ownAcceptances()).thenAnswer(
      (_) async => [
        if (accepted != null) ...[
          TermsVersion(document: LegalDocument.termsOfUse, version: accepted),
          TermsVersion(
            document: LegalDocument.privacyPolicy,
            version: accepted,
          ),
        ],
      ],
    );
  }

  void ownProfile({
    String name = 'Ana Souza',
    String? nickname,
    String? photoPath,
    String? phone,
    bool phoneVisible = false,
    PixKeyType? pixKeyType,
    String? pixKey,
  }) {
    when(() => profiles.fetchOwn()).thenAnswer(
      (_) async => OwnProfile(
        profile: Profile(
          id: anaId,
          name: name,
          nickname: nickname,
          displayName: nickname ?? name,
          photoPath: photoPath,
        ),
        private: ProfilePrivate(
          phone: phone,
          phoneVisible: phoneVisible,
          pixKeyType: pixKeyType,
          pixKey: pixKey,
        ),
      ),
    );
    when(() => profiles.avatarUrl(any())).thenAnswer(
      (_) async => 'http://127.0.0.1:54321/storage/v1/object/sign/avatars/x',
    );
  }

  /// Meus grupos (docs/ui/telas.md, 6.1).
  void myGroups(List<GroupSummary> list) {
    when(() => groups.fetchMyGroups()).thenAnswer((_) async => list);
  }

  /// O grupo como o detalhe o lê. Cada leitura chama [read] de novo, para o
  /// teste trocar o grupo depois de uma ação (a tela relê do servidor).
  void group(GroupDetail Function() read) {
    final id = read().id;
    when(() => groups.fetchGroup(id)).thenAnswer((_) async => read());
  }

  /// O RLS não devolve o grupo: quem não é membro, ex-membro, grupo excluído.
  void groupNotFound(String id) {
    when(() => groups.fetchGroup(id))
        .thenAnswer((_) async => throw const AppException(ErrorCode.notFound));
  }

  void members(String groupId, List<GroupMember> Function() read) {
    when(() => groups.fetchMembers(groupId)).thenAnswer((_) async => read());
  }

  void requests(String groupId, List<JoinRequest> Function() read) {
    when(() => groups.fetchPendingRequests(groupId))
        .thenAnswer((_) async => read());
  }

  /// Meus jogos (docs/ui/telas.md, 7.1).
  void myGames(List<GameSummary> list) {
    when(() => games.fetchMyGames()).thenAnswer((_) async => list);
  }

  /// Os jogos do grupo `open` e `confirmed` (telas.md, 7.6).
  void groupGames(String groupId, List<GameSummary> list) {
    when(() => games.fetchGroupGames(groupId)).thenAnswer((_) async => list);
  }

  /// O jogo como o detalhe o lê. Cada leitura chama [read] de novo, para o
  /// teste trocar o jogo depois de uma ação ou de um evento do Realtime.
  void game(GameDetail Function() read) {
    final id = read().id;
    when(() => games.fetchGame(id)).thenAnswer((_) async => read());
  }

  /// O RLS não devolve o jogo: quem não pode vê-lo, ID que não existe.
  void gameNotFound(String id) {
    when(() => games.fetchGame(id))
        .thenAnswer((_) async => throw const AppException(ErrorCode.notFound));
  }

  /// O dublê do Realtime avisa que o jogo mudou no servidor (S51).
  Future<void> realtimeEvent(WidgetTester tester, String gameId) async {
    final onChange = _realtime[gameId];
    expect(onChange, isNotNull, reason: 'o detalhe não assinou o Realtime');
    onChange!();
    await tester.pumpAndSettle();
  }

  bool isWatching(String gameId) => _realtime.containsKey(gameId);

  /// Abre o app num celular de 360 x 760 dp e, se pedido, vai à rota.
  Future<void> pumpApp(
    WidgetTester tester, {
    String? location,
    double textScale = 1.0,
    Size size = const Size(360, 760),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    if (textScale != 1.0) {
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    }
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const VoleiInApp(),
      ),
    );
    await tester.pumpAndSettle();

    if (location != null) await go(tester, location);
  }

  Future<void> go(WidgetTester tester, String location) async {
    router.go(location);
    await tester.pumpAndSettle();
  }

  /// Empilha a rota sobre a atual, como faz o toque numa linha ou num botão.
  Future<void> push(WidgetTester tester, String location) async {
    router.push(location);
    await tester.pumpAndSettle();
  }
}

/// Botão pelo texto, qualquer que seja a variante (com ou sem ícone).
Finder buttonWithText<T extends ButtonStyleButton>(String text) =>
    find.ancestor(of: find.text(text), matching: find.bySubtype<T>());

/// Se o botão com este texto aceita toque.
bool isEnabled<T extends ButtonStyleButton>(WidgetTester tester, String text) =>
    tester.widget<T>(buttonWithText<T>(text)).onPressed != null;
