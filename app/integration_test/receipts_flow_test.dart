import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:voleiin/app.dart';
import 'package:voleiin/core/env.dart';
import 'package:voleiin/core/format/date_time.dart';
import 'package:voleiin/core/receipt_picker.dart';
import 'package:voleiin/core/router/app_router.dart';
import 'package:voleiin/shared/widgets/bottom_nav.dart';

import '../test/helpers/test_app.dart';

/// Cenários L24 e L25 de docs/testes-referencia.md, seção 14.8
/// (specs/010-pagamentos-etapa-b). Como o L20 a L23, usam o jogo "Quinta
/// aguardando conclusão" do seed (`...0209`, R$ 90,00 e 3 vagas, com Ana,
/// Bruno e Carla; docs/setup.md, seção 8), que a Ana conclui pela API antes
/// de abrir o app. Cada fluxo roda logo depois de um `supabase db reset`.
///
/// A `process-receipt` local fala com o dublê da Claude API pelo
/// `ANTHROPIC_BASE_URL` do `supabase functions serve` dos testes. O dublê
/// responde pelo arquivo: a imagem [legibleReceipt] tem a leitura boa do
/// valor do Bruno (R$ 30,00, a chave da Ana, a hora atual e um código do Pix
/// novo); a [illegibleReceipt], os seis campos nulos. O seletor de arquivo do
/// app é trocado por um dublê, que devolve a imagem do fluxo.
///
/// ```bash
/// scripts/integration-test.sh integration_test/receipts_flow_test.dart \
///   --plain-name L24
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const password = 'voleiin123';
  const awaitingId = '00000000-0000-0000-0000-000000000209';
  const brunoId = '00000000-0000-0000-0000-00000000000b';

  setUpAll(() async {
    Env.ensureComplete();
    initTimeZones();
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabasePublishableKey,
    );
  });

  Future<void> pumpUntil(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 100));
      if (finder.evaluate().isNotEmpty) return;
    }
    throw TestFailure('Não apareceu em ${timeout.inSeconds} s: $finder');
  }

  Future<void> pumpUntilGone(WidgetTester tester, Finder finder) async {
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 100));
      if (finder.evaluate().isEmpty) return;
    }
    throw TestFailure('Não sumiu em 20 s: $finder');
  }

  Future<void> tapReady(WidgetTester tester, Finder finder) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await pumpUntil(tester, finder);
    await tester.ensureVisible(finder);
    await pumpUntil(tester, finder.hitTestable());
    await tester.tap(finder);
  }

  Finder button<T extends Widget>(String text) =>
      find.ancestor(of: find.text(text), matching: find.byType(T));

  Finder inSheet(Finder finder) =>
      find.descendant(of: find.byType(BottomSheet), matching: finder);

  Future<void> signIn(String email) async {
    final client = Supabase.instance.client;
    await client.auth.signOut();
    await client.auth.signInWithPassword(email: email, password: password);
  }

  /// A Ana conclui o jogo. Se o pg_cron já o concluiu, segue.
  Future<void> completeAsAna() async {
    await signIn('ana@voleiin.test');
    try {
      await Supabase.instance.client.rpc(
        'complete_game',
        params: {'p_game_id': awaitingId},
      );
    } on PostgrestException catch (error) {
      if (error.message != 'GAME_NOT_OPEN') rethrow;
    }
  }

  /// O comprovante Em análise do Bruno no jogo do fluxo, lido pela sessão atual.
  Future<String> underReviewReceiptId() async {
    final client = Supabase.instance.client;
    final charge = await client
        .from('charges')
        .select('id')
        .eq('game_id', awaitingId)
        .eq('payer_id', brunoId)
        .single();
    final receipt = await client
        .from('receipts')
        .select('id')
        .eq('charge_id', charge['id'] as String)
        .eq('status', 'under_review')
        .single();
    return receipt['id'] as String;
  }

  /// Abre o app do zero, com a sessão atual e o seletor trocado.
  Future<void> openApp(WidgetTester tester, Uint8List image) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          receiptPickerProvider.overrideWithValue(_FixedPicker(image)),
        ],
        child: const VoleiInApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openCharges(WidgetTester tester) async {
    final container = ProviderScope.containerOf(
      tester.element(find.byType(VoleiInApp)),
    );
    container.read(routerProvider).go('/charges');
    await pumpUntil(
      tester,
      find.descendant(
        of: find.byType(VoleiBottomNav),
        matching: find.text(l10nPt.navCharges),
      ),
    );
  }

  /// O Bruno abre a linha do jogo em A pagar e envia a imagem.
  Future<void> sendAsBruno(WidgetTester tester) async {
    await openCharges(tester);
    await tapReady(tester, find.byKey(const Key('toPay-$awaitingId')));
    await tapReady(tester, button<FilledButton>(l10nPt.receiptSend));
    await tapReady(tester, inSheet(find.text(l10nPt.receiptPickImage)));
    await tapReady(
      tester,
      inSheet(button<FilledButton>(l10nPt.receiptSendAction)),
    );
  }

  testWidgets('L24: Bruno envia um comprovante com a leitura boa', (
    tester,
  ) async {
    await completeAsAna();
    await signIn('bruno@voleiin.test');
    await openApp(tester, legibleReceipt);

    await sendAsBruno(tester);
    await pumpUntil(
      tester,
      inSheet(find.text(l10nPt.receiptApproved)),
      timeout: const Duration(seconds: 40),
    );
    await tapReady(tester, inSheet(button<FilledButton>(l10nPt.receiptDone)));

    // O valor relido, Pago.
    await pumpUntil(tester, find.text(l10nPt.chargeStatusPaid));
    expect(find.text(l10nPt.receiptSend), findsNothing);

    // A linha some de A pagar.
    await tapReady(tester, find.byTooltip(l10nPt.commonBack));
    await pumpUntil(tester, find.text(l10nPt.chargesTitle));
    await pumpUntilGone(tester, find.byKey(const Key('toPay-$awaitingId')));
  });

  testWidgets('L25: Ana recusa o comprovante ilegível do Bruno', (
    tester,
  ) async {
    await completeAsAna();
    await signIn('bruno@voleiin.test');
    await openApp(tester, illegibleReceipt);

    await sendAsBruno(tester);
    await pumpUntil(
      tester,
      inSheet(find.text(l10nPt.receiptUnderReview('Ana'))),
      timeout: const Duration(seconds: 40),
    );
    await tapReady(tester, inSheet(button<FilledButton>(l10nPt.receiptDone)));
    await pumpUntil(tester, find.text(l10nPt.chargeUnderReviewNotice('Ana')));

    // A Ana entra e recusa por Para conferir.
    await signIn('ana@voleiin.test');
    await openApp(tester, illegibleReceipt);
    await openCharges(tester);
    // O seed "Quinta com comprovantes" (`...0212`) já tem um comprovante do
    // Bruno Em análise para a Ana: são dois, e o do fluxo é o do jogo `...0209`.
    await pumpUntil(tester, find.text(l10nPt.chargesToReview(2)));
    final receiptId = await underReviewReceiptId();
    await tapReady(tester, find.byKey(Key('toReview-$receiptId')));
    // A API leu, sem nada legível: as quatro linhas Não lido.
    await pumpUntil(tester, find.text(l10nPt.receiptCheckTitle));
    expect(find.text(l10nPt.receiptCheckUnread), findsNWidgets(4));
    await tapReady(tester, button<OutlinedButton>(l10nPt.receiptReject));
    await pumpUntil(tester, inSheet(find.byType(TextField)));
    await tester.enterText(
      inSheet(find.byType(TextField)),
      'Não dá para ler o comprovante.',
    );
    await tapReady(tester, inSheet(button<FilledButton>(l10nPt.receiptReject)));
    await pumpUntil(tester, find.text(l10nPt.receiptRejectedByYou));

    // O Bruno entra: Pendente, o comprovante Recusado e a observação.
    await signIn('bruno@voleiin.test');
    await openApp(tester, illegibleReceipt);
    await openCharges(tester);
    await tapReady(tester, find.byKey(const Key('toPay-$awaitingId')));
    await pumpUntil(tester, find.text(l10nPt.chargeStatusPending));
    await pumpUntil(tester, find.text(l10nPt.receiptStatusRejected));
    expect(
      find.text(l10nPt.receiptNoteQuoted('Não dá para ler o comprovante.')),
      findsOneWidget,
    );
    expect(button<FilledButton>(l10nPt.receiptSend), findsOneWidget);
  });
}

/// O seletor de arquivo do fluxo: sempre a mesma imagem.
class _FixedPicker implements ReceiptPicker {
  _FixedPicker(this.image);

  final Uint8List image;

  @override
  Future<PickedFile?> pickImage() async =>
      PickedFile(name: 'comprovante.png', bytes: image);

  @override
  Future<PickedFile?> pickPdf() async => null;
}

/// PNG branco de 2 × 2: o dublê da API responde a leitura boa.
final legibleReceipt = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x02,
  0x08, 0x02, 0x00, 0x00, 0x00, 0xFD, 0xD4, 0x9A, 0x73, 0x00, 0x00, 0x00,
  0x0E, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0x0F, 0x06, 0x0C,
  0x10, 0x0A, 0x00, 0x53, 0xBA, 0x0B, 0xF5, 0x98, 0xAC, 0x20, 0x67, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// PNG preto de 2 × 2: o dublê da API responde os seis campos nulos.
final illegibleReceipt = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x02,
  0x08, 0x02, 0x00, 0x00, 0x00, 0xFD, 0xD4, 0x9A, 0x73, 0x00, 0x00, 0x00,
  0x0B, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x60, 0x40, 0x06, 0x00,
  0x00, 0x0E, 0x00, 0x01, 0xA9, 0x91, 0x73, 0xB1, 0x00, 0x00, 0x00, 0x00,
  0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);
