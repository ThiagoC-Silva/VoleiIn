import 'package:flutter/material.dart';

// Base escura do design system (docs/design/DESIGN.md). As telas leem cor e texto daqui,
// por Theme.of e VoleiCores, nunca de um hex solto no widget. A base clara entra com o
// grupo H, que é quem tem a escolha de aparência.

const _fundo = Color(0xFF0F1833);
const _superficie = Color(0xFF192853);
const _superficieAlta = Color(0xFF2A3A68);
const _texto = Color(0xFFECF4F7);
const _textoSecundario = Color(0xFFA9B6D3);
const _amarelo = Color(0xFFFFE14F);
const _amareloPressionado = Color(0xFFE6C835);
const _navy = Color(0xFF192853);
const _erro = Color(0xFFFF9B90);

/// Fundo, texto e ponto de um selo de status.
@immutable
class TomSelo {
  const TomSelo({required this.fundo, required this.texto, required this.ponto});

  final Color fundo;
  final Color texto;
  final Color ponto;
}

/// Cores de significado e de selo, que o ColorScheme do Material não tem.
/// Os blocos levam sempre texto [sobreBloco], nunca branco.
@immutable
class VoleiCores extends ThemeExtension<VoleiCores> {
  const VoleiCores({
    required this.jogo,
    required this.deve,
    required this.recebe,
    required this.espera,
    required this.rateio,
    required this.sobreBloco,
    required this.primarioPressionado,
    required this.destrutivo,
    required this.ok,
    required this.warn,
    required this.bad,
    required this.info,
    required this.wait,
    required this.neu,
  });

  final Color jogo;
  final Color deve;
  final Color recebe;
  final Color espera;
  final Color rateio;
  final Color sobreBloco;
  final Color primarioPressionado;
  final Color destrutivo;
  final TomSelo ok;
  final TomSelo warn;
  final TomSelo bad;
  final TomSelo info;
  final TomSelo wait;
  final TomSelo neu;

  static const escuro = VoleiCores(
    jogo: Color(0xFFFFE14F),
    deve: Color(0xFFFF8F6B),
    recebe: Color(0xFF7CDCC8),
    espera: Color(0xFFB8A6FF),
    rateio: Color(0xFF8EC5FF),
    sobreBloco: _navy,
    primarioPressionado: _amareloPressionado,
    destrutivo: Color(0xFFD93A2B),
    ok: TomSelo(fundo: Color(0x2E2ECC71), texto: Color(0xFF7BE3A6), ponto: Color(0xFF2ECC71)),
    warn: TomSelo(fundo: Color(0x2EFF9F43), texto: Color(0xFFFFC48A), ponto: Color(0xFFFF9F43)),
    bad: TomSelo(fundo: Color(0x38E74C3C), texto: Color(0xFFFF9B90), ponto: Color(0xFFE74C3C)),
    info: TomSelo(fundo: _superficieAlta, texto: _texto, ponto: Color(0xFF8EC5FF)),
    wait: TomSelo(fundo: Color(0x33B8A6FF), texto: Color(0xFFD3C9FF), ponto: Color(0xFFB8A6FF)),
    neu: TomSelo(fundo: _superficieAlta, texto: _textoSecundario, ponto: _textoSecundario),
  );

  static VoleiCores of(BuildContext context) => Theme.of(context).extension<VoleiCores>()!;

  @override
  VoleiCores copyWith() => this;

  // Um modo só por enquanto: não há o que interpolar.
  @override
  VoleiCores lerp(VoleiCores? other, double t) => t < 0.5 || other == null ? this : other;
}

// Tokens de tipografia de DESIGN.md mapeados no TextTheme:
//   display*      number.hero / xl / lg — Bebas Neue, só números
//   headlineSmall number.md
//   headlineLarge title.xl · headlineMedium title.lg — Montserrat 800
//   titleLarge    barra interna · titleMedium title.md — Montserrat 700
//   body*         body.lg / body.md / caption — Roboto
//   labelLarge    label, o texto dos botões
// Tokens com faixa de tamanho (number.xl 52–64, por exemplo) saem do estilo com copyWith.
const _textos = TextTheme(
  displayLarge: TextStyle(fontFamily: 'BebasNeue', letterSpacing: 0.3, height: 1, fontSize: 84),
  displayMedium: TextStyle(fontFamily: 'BebasNeue', letterSpacing: 0.3, height: 1, fontSize: 56),
  displaySmall: TextStyle(fontFamily: 'BebasNeue', letterSpacing: 0.3, height: 1, fontSize: 40),
  headlineSmall: TextStyle(fontFamily: 'BebasNeue', letterSpacing: 0.3, height: 1, fontSize: 26),
  headlineLarge: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w800, fontSize: 28, letterSpacing: 0),
  headlineMedium: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w800, fontSize: 22, letterSpacing: 0),
  titleLarge: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w700, fontSize: 18, letterSpacing: 0),
  titleMedium: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 0),
  // O Material 3 abre o espaçamento entre letras do texto (0,5 no bodyLarge); o design não.
  bodyLarge: TextStyle(fontSize: 16, height: 1.5, letterSpacing: 0),
  bodyMedium: TextStyle(fontSize: 14, height: 20 / 14, letterSpacing: 0),
  bodySmall: TextStyle(fontSize: 12, height: 16 / 12, letterSpacing: 0),
  labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0),
);

const _pilula = StadiumBorder();
const _alturaControle = 56.0;

OutlineInputBorder _borda(Color cor, double largura) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: cor, width: largura),
    );

final temaVoleiIn = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: const ColorScheme(
    brightness: Brightness.dark,
    primary: _amarelo,
    onPrimary: _navy,
    secondary: _texto,
    onSecondary: _navy,
    surface: _superficie,
    surfaceContainerHigh: _superficieAlta,
    onSurface: _texto,
    onSurfaceVariant: _textoSecundario,
    outline: _superficieAlta,
    outlineVariant: _superficieAlta,
    error: _erro,
    onError: _navy,
  ),
  scaffoldBackgroundColor: _fundo,
  canvasColor: _fundo,
  dividerColor: _superficieAlta,
  textTheme: _textos.apply(bodyColor: _texto, displayColor: _texto),
  extensions: const [VoleiCores.escuro],
  appBarTheme: AppBarTheme(
    backgroundColor: _fundo,
    foregroundColor: _texto,
    elevation: 0,
    scrolledUnderElevation: 0,
    titleTextStyle: _textos.titleLarge!.copyWith(color: _texto),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size.fromHeight(_alturaControle)),
      shape: const WidgetStatePropertyAll(_pilula),
      textStyle: WidgetStatePropertyAll(_textos.labelLarge),
      backgroundColor: WidgetStateProperty.resolveWith((estado) {
        if (estado.contains(WidgetState.disabled)) return _superficieAlta;
        if (estado.contains(WidgetState.pressed)) return _amareloPressionado;
        return _amarelo;
      }),
      foregroundColor: WidgetStateProperty.resolveWith(
        (estado) => estado.contains(WidgetState.disabled) ? _textoSecundario : _navy,
      ),
      iconSize: const WidgetStatePropertyAll(22),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size.fromHeight(_alturaControle)),
      shape: const WidgetStatePropertyAll(_pilula),
      textStyle: WidgetStatePropertyAll(_textos.labelLarge),
      side: const WidgetStatePropertyAll(BorderSide(color: _superficieAlta, width: 1.5)),
      foregroundColor: WidgetStateProperty.resolveWith(
        (estado) => estado.contains(WidgetState.disabled) ? _textoSecundario : _texto,
      ),
      iconSize: const WidgetStatePropertyAll(22),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(44, 44)),
      shape: const WidgetStatePropertyAll(_pilula),
      textStyle: WidgetStatePropertyAll(_textos.labelLarge),
      foregroundColor: WidgetStateProperty.resolveWith(
        (estado) => estado.contains(WidgetState.disabled) ? _textoSecundario : _amarelo,
      ),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: _superficie,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    hintStyle: _textos.bodyLarge!.copyWith(color: _textoSecundario),
    helperStyle: _textos.bodySmall!.copyWith(color: _textoSecundario, fontSize: 13),
    errorStyle: _textos.bodySmall!.copyWith(color: _erro),
    suffixIconColor: _textoSecundario,
    border: _borda(_superficieAlta, 1.5),
    enabledBorder: _borda(_superficieAlta, 1.5),
    disabledBorder: _borda(_superficieAlta, 1.5),
    focusedBorder: _borda(_amarelo, 2),
    errorBorder: _borda(_erro, 2),
    focusedErrorBorder: _borda(_erro, 2),
  ),
  textSelectionTheme: const TextSelectionThemeData(
    cursorColor: _amarelo,
    selectionColor: Color(0x66FFE14F),
    selectionHandleColor: _amarelo,
  ),
  progressIndicatorTheme: const ProgressIndicatorThemeData(color: _amarelo),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: _superficieAlta,
    contentTextStyle: _textos.bodyMedium!.copyWith(color: _texto),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
);
