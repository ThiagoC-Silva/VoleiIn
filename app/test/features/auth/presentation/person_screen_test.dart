import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voleiin/core/errors/error_code.dart';
import 'package:voleiin/features/auth/domain/profile.dart';

import '../../../helpers/harness.dart';
import '../../../helpers/test_app.dart';

/// Cenário S34 de docs/testes-referencia.md, seção 11.6 (docs/ui/telas.md,
/// 6.9).
void main() {
  late TestHarness h;

  setUp(() {
    h = TestHarness();
    h.signedIn();
  });

  Future<void> open(WidgetTester tester, String userId) async {
    await h.pumpApp(tester, location: '/groups');
    await h.push(tester, '/people/$userId');
  }

  testWidgets('S34: com apelido, o apelido em destaque e o nome embaixo', (
    tester,
  ) async {
    when(() => h.profiles.fetchProfile(brunoId)).thenAnswer(
      (_) async => const Profile(
        id: brunoId,
        name: 'Bruno Lima',
        nickname: 'Brunão',
        displayName: 'Brunão',
      ),
    );
    await open(tester, brunoId);

    final title = find.text('Brunão');
    final name = find.text('Bruno Lima');
    expect(title, findsOneWidget);
    expect(name, findsOneWidget);
    expect(tester.getTopLeft(title).dy, lessThan(tester.getTopLeft(name).dy));
  });

  testWidgets('S34: sem apelido, só o nome', (tester) async {
    when(() => h.profiles.fetchProfile(diegoId)).thenAnswer(
      (_) async =>
          const Profile(id: diegoId, name: 'Diego', displayName: 'Diego'),
    );
    await open(tester, diegoId);

    expect(find.text('Diego'), findsOneWidget);
  });

  testWidgets('S34: perfil que o repositório não acha', (tester) async {
    when(() => h.profiles.fetchProfile(diegoId))
        .thenAnswer((_) async => throw const AppException(ErrorCode.notFound));
    await open(tester, diegoId);

    expect(find.text(l10nPt.errorNotFound), findsOneWidget);
  });

  testWidgets('a barra inferior continua, com a aba Grupos', (tester) async {
    when(() => h.profiles.fetchProfile(brunoId)).thenAnswer(
      (_) async =>
          const Profile(id: brunoId, name: 'Bruno', displayName: 'Bruno'),
    );
    await open(tester, brunoId);

    expect(find.text(l10nPt.navGroups), findsOneWidget);
  });

  group('S58: telefone visível (fatia 4, etapa C)', () {
    setUp(() {
      when(() => h.profiles.fetchProfile(anaId)).thenAnswer(
        (_) async => const Profile(id: anaId, name: 'Ana', displayName: 'Ana'),
      );
    });

    testWidgets('a linha Telefone, Ligar e WhatsApp', (tester) async {
      when(() => h.profiles.fetchContactPhone(anaId))
          .thenAnswer((_) async => '+5586999998888');
      h.signedIn(userId: brunoId);
      await open(tester, anaId);

      expect(find.text(l10nPt.personPhone), findsOneWidget);
      expect(find.text('(86) 99999-8888'), findsOneWidget);
      await tester.tap(find.text(l10nPt.personCall));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10nPt.personWhatsapp));
      await tester.pumpAndSettle();
      expect(h.links.opened, [
        Uri.parse('tel:+5586999998888'),
        Uri.parse('https://wa.me/5586999998888'),
      ]);
    });

    testWidgets('o link não abre: commonCannotOpenLink', (tester) async {
      when(() => h.profiles.fetchContactPhone(anaId))
          .thenAnswer((_) async => '+5586999998888');
      h.links.works = false;
      h.signedIn(userId: brunoId);
      await open(tester, anaId);
      await tester.tap(find.text(l10nPt.personCall));
      await tester.pumpAndSettle();
      expect(find.text(l10nPt.commonCannotOpenLink), findsOneWidget);
    });

    testWidgets('telefone nulo: sem a linha', (tester) async {
      h.signedIn(userId: brunoId);
      await open(tester, anaId);
      expect(find.text(l10nPt.personPhone), findsNothing);
      expect(find.text(l10nPt.personCall), findsNothing);
    });
  });
}
