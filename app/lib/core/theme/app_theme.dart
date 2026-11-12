// Tema único e escuro do app (docs/ui/design-system.md, seção 9).
// Cor e estilo de texto no widget vêm daqui, nunca de um hex solto.
import 'package:flutter/material.dart';

const _background = Color(0xFF0F1833);
const _surface = Color(0xFF192853);
const _surfaceHigh = Color(0xFF2A3A68);
const _onSurface = Color(0xFFECF4F7);
const _onSurfaceVariant = Color(0xFFA9B6D3);
const _primary = Color(0xFFFFE14F);
const _primaryPressed = Color(0xFFE6C835);
const _navy = Color(0xFF192853);
const _errorText = Color(0xFFFF9B90);

@immutable
class BadgeTone {
  const BadgeTone({
    required this.background,
    required this.text,
    required this.dot,
  });
  final Color background;
  final Color text;
  final Color dot;
}

/// Cores de significado e de selo, que o ColorScheme do Material não tem.
/// Os blocos levam sempre texto [onBlock], nunca branco.
@immutable
class VoleiColors extends ThemeExtension<VoleiColors> {
  const VoleiColors({
    required this.game,
    required this.owe,
    required this.receive,
    required this.wait,
    required this.split,
    required this.onBlock,
    required this.primaryPressed,
    required this.destructive,
    required this.ok,
    required this.warn,
    required this.bad,
    required this.info,
    required this.waiting,
    required this.neutral,
  });

  final Color game, owe, receive, wait, split, onBlock, primaryPressed, destructive;
  final BadgeTone ok, warn, bad, info, waiting, neutral;

  static const dark = VoleiColors(
    game: Color(0xFFFFE14F),
    owe: Color(0xFFFF8F6B),
    receive: Color(0xFF7CDCC8),
    wait: Color(0xFFB8A6FF),
    split: Color(0xFF8EC5FF),
    onBlock: _navy,
    primaryPressed: _primaryPressed,
    destructive: Color(0xFFD93A2B),
    ok: BadgeTone(
      background: Color(0x2E2ECC71),
      text: Color(0xFF7BE3A6),
      dot: Color(0xFF2ECC71),
    ),
    warn: BadgeTone(
      background: Color(0x2EFF9F43),
      text: Color(0xFFFFC48A),
      dot: Color(0xFFFF9F43),
    ),
    bad: BadgeTone(
      background: Color(0x38E74C3C),
      text: Color(0xFFFF9B90),
      dot: Color(0xFFE74C3C),
    ),
    info: BadgeTone(background: _surfaceHigh, text: _onSurface, dot: Color(0xFF8EC5FF)),
    waiting: BadgeTone(
      background: Color(0x33B8A6FF),
      text: Color(0xFFD3C9FF),
      dot: Color(0xFFB8A6FF),
    ),
    neutral: BadgeTone(
      background: _surfaceHigh,
      text: _onSurfaceVariant,
      dot: _onSurfaceVariant,
    ),
  );

  static VoleiColors of(BuildContext context) =>
      Theme.of(context).extension<VoleiColors>()!;

  @override
  VoleiColors copyWith() => this;

  // Uma base só (modo escuro): não há o que interpolar.
  @override
  VoleiColors lerp(VoleiColors? other, double t) => this;
}

// Tokens de tipografia no TextTheme:
//   displayLarge/Medium/Small  number.hero / xl / lg (Bebas Neue, só números)
//   headlineLarge/Medium       title.xl / title.lg (Montserrat 800)
//   titleLarge/Medium          title.md / title.sm (Montserrat 700)
//   bodyLarge/Medium/Small     body.lg / body.md / caption (Roboto)
//   labelLarge                 label (botões)
// number.md sai de displaySmall com copyWith(fontSize: 26).
const _text = TextTheme(
  displayLarge: TextStyle(
    fontFamily: 'BebasNeue',
    letterSpacing: 0.3,
    height: 1,
    fontSize: 84,
  ),
  displayMedium: TextStyle(
    fontFamily: 'BebasNeue',
    letterSpacing: 0.3,
    height: 1,
    fontSize: 56,
  ),
  displaySmall: TextStyle(
    fontFamily: 'BebasNeue',
    letterSpacing: 0.3,
    height: 1,
    fontSize: 40,
  ),
  headlineLarge: TextStyle(
    fontFamily: 'Montserrat',
    fontWeight: FontWeight.w800,
    fontSize: 28,
  ),
  headlineMedium: TextStyle(
    fontFamily: 'Montserrat',
    fontWeight: FontWeight.w800,
    fontSize: 22,
  ),
  titleLarge: TextStyle(
    fontFamily: 'Montserrat',
    fontWeight: FontWeight.w700,
    fontSize: 18,
  ),
  titleMedium: TextStyle(
    fontFamily: 'Montserrat',
    fontWeight: FontWeight.w700,
    fontSize: 15,
  ),
  // O Material 3 abre o espaçamento entre letras do texto; o design não.
  bodyLarge: TextStyle(fontSize: 16, height: 1.5, letterSpacing: 0),
  bodyMedium: TextStyle(fontSize: 14, height: 20 / 14, letterSpacing: 0),
  bodySmall: TextStyle(fontSize: 12, height: 16 / 12, letterSpacing: 0),
  labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0),
);

OutlineInputBorder _border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: width),
    );

final appTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: const ColorScheme(
    brightness: Brightness.dark,
    primary: _primary,
    onPrimary: _navy,
    secondary: _onSurface,
    onSecondary: _navy,
    surface: _surface,
    surfaceContainerHigh: _surfaceHigh,
    onSurface: _onSurface,
    onSurfaceVariant: _onSurfaceVariant,
    outline: _surfaceHigh,
    outlineVariant: _surfaceHigh,
    error: _errorText,
    onError: _navy,
  ),
  scaffoldBackgroundColor: _background,
  canvasColor: _background,
  dividerColor: _surfaceHigh,
  textTheme: _text.apply(bodyColor: _onSurface, displayColor: _onSurface),
  extensions: const [VoleiColors.dark],
  materialTapTargetSize: MaterialTapTargetSize.padded, // 48 dp (RNF05)
  appBarTheme: AppBarTheme(
    backgroundColor: _background,
    foregroundColor: _onSurface,
    elevation: 0,
    scrolledUnderElevation: 0,
    titleTextStyle: _text.titleLarge!.copyWith(color: _onSurface),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size.fromHeight(56)),
      shape: const WidgetStatePropertyAll(StadiumBorder()),
      textStyle: WidgetStatePropertyAll(_text.labelLarge),
      backgroundColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.disabled)) return _surfaceHigh;
        if (s.contains(WidgetState.pressed)) return _primaryPressed;
        return _primary;
      }),
      foregroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.disabled) ? _onSurfaceVariant : _navy,
      ),
      iconSize: const WidgetStatePropertyAll(22),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size.fromHeight(56)),
      shape: const WidgetStatePropertyAll(StadiumBorder()),
      textStyle: WidgetStatePropertyAll(_text.labelLarge),
      side: const WidgetStatePropertyAll(
        BorderSide(color: _surfaceHigh, width: 1.5),
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.disabled) ? _onSurfaceVariant : _onSurface,
      ),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
      shape: const WidgetStatePropertyAll(StadiumBorder()),
      textStyle: WidgetStatePropertyAll(_text.labelLarge),
      foregroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.disabled) ? _onSurfaceVariant : _primary,
      ),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: _surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    hintStyle: _text.bodyLarge!.copyWith(color: _onSurfaceVariant),
    errorStyle: _text.bodySmall!.copyWith(color: _errorText),
    border: _border(_surfaceHigh, 1.5),
    enabledBorder: _border(_surfaceHigh, 1.5),
    disabledBorder: _border(_surfaceHigh, 1.5),
    focusedBorder: _border(_primary, 2),
    errorBorder: _border(_errorText, 2),
    focusedErrorBorder: _border(_errorText, 2),
  ),
  progressIndicatorTheme: const ProgressIndicatorThemeData(color: _primary),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: _surfaceHigh,
    contentTextStyle: _text.bodyMedium!.copyWith(color: _onSurface),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
);
