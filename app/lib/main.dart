import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/env.dart';
import 'core/format/date_time.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Para aqui se faltar variável de ambiente (docs/setup.md, seção 5.1).
  Env.ensureComplete();

  // Fuso America/Fortaleza, usado em toda exibição de data e hora (RN01).
  initTimeZones();

  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabasePublishableKey,
  );

  runApp(const ProviderScope(child: VoleiInApp()));
}
