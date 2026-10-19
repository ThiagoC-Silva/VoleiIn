import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/rotas.dart';
import 'core/supabase.dart';
import 'core/tema.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await iniciarSupabase();
  runApp(const ProviderScope(child: VoleiInApp()));
}

class VoleiInApp extends StatelessWidget {
  const VoleiInApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VoleiIn',
      theme: temaVoleiIn,
      home: const Raiz(),
    );
  }
}
