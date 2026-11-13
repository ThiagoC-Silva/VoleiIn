import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:voleiin/core/theme/app_theme.dart';
import 'package:voleiin/shared/widgets/arrow_rows.dart';
import 'package:voleiin/shared/widgets/avatar.dart';
import 'package:voleiin/shared/widgets/bottom_nav.dart';
import 'package:voleiin/shared/widgets/form_fields.dart';

import '../../helpers/test_app.dart';

/// Diferenças entre o app e o design system (docs/ui/design-system.md),
/// achadas na conferência das telas da fatia 2 contra os PNG (T051).
void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    TestApp(
      child: Scaffold(body: Center(child: child)),
    ),
  );

  testWidgets('o título da linha de lista é Roboto 700 16, e não Montserrat '
      '(seção 5)', (tester) async {
    await pump(
      tester,
      ArrowRow(icon: Symbols.edit, title: 'Editar perfil', onTap: () {}),
    );

    final style = tester.widget<Text>(find.text('Editar perfil')).style!;
    expect(style.fontFamily, isNot('Montserrat'));
    expect(style.fontWeight, FontWeight.w700);
    expect(style.fontSize, 16);
  });

  testWidgets('o avatar de "você" é amarelo (seção 3.4)', (tester) async {
    await pump(
      tester,
      const VoleiAvatar(id: 'qualquer-id', name: 'Ana Souza', isYou: true),
    );

    final colors = tester
        .widgetList<Container>(
          find.descendant(
            of: find.byType(VoleiAvatar),
            matching: find.byType(Container),
          ),
        )
        .map((c) => c.color);
    expect(colors, contains(appTheme.colorScheme.primary));
  });

  testWidgets('o item ativo da navegação sobe acima da barra, com anel na cor '
      'do fundo (seção 7.6)', (tester) async {
    await tester.pumpWidget(
      TestApp(
        child: Scaffold(
          bottomNavigationBar: VoleiBottomNav(
            currentIndex: 1,
            onSelected: (_) {},
            destinations: const [
              NavDestinationData(icon: Symbols.home, label: 'Jogos'),
              NavDestinationData(icon: Symbols.person, label: 'Perfil'),
            ],
          ),
        ),
      ),
    );

    final active = find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration! as BoxDecoration).color ==
              appTheme.colorScheme.primary,
    );
    expect(active, findsOneWidget);
    final decoration =
        tester.widget<Container>(active).decoration! as BoxDecoration;
    final ring = (decoration.border! as Border).top;
    expect(ring.width, 5);
    expect(ring.color, appTheme.scaffoldBackgroundColor);
    expect(
      tester.getTopLeft(active).dy,
      lessThan(tester.getTopLeft(find.byType(VoleiBottomNav)).dy),
    );
  });

  testWidgets('o texto de ajuda começa na borda do campo, como o rótulo', (
    tester,
  ) async {
    await pump(
      tester,
      Form(
        child: LabeledField(
          label: 'Apelido',
          controller: TextEditingController(),
          helperText: 'Aparece no lugar do nome nas listas',
        ),
      ),
    );

    expect(
      tester.getTopLeft(find.text('Aparece no lugar do nome nas listas')).dx,
      moreOrLessEquals(tester.getTopLeft(find.byType(TextFormField)).dx),
    );
  });

  testWidgets('o prefixo fixo aparece com o campo vazio (telas.md, 5.8)', (
    tester,
  ) async {
    await pump(
      tester,
      Form(
        child: LabeledField(
          label: 'Telefone',
          controller: TextEditingController(),
          prefixText: '+55  ',
        ),
      ),
    );

    final prefix = find.text('+55  ');
    expect(prefix, findsOneWidget);
    final hidden = tester
        .widgetList<AnimatedOpacity>(
          find.ancestor(of: prefix, matching: find.byType(AnimatedOpacity)),
        )
        .where((o) => o.opacity < 1);
    expect(hidden, isEmpty);
  });
}
