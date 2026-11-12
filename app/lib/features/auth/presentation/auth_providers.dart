import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_repository.dart';

/// Sessão: um `StreamProvider` sobre `onAuthStateChange`
/// (docs/arquitetura-app.md, seção 5). O roteador escuta este provider.
final authStateProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(authRepositoryProvider).onAuthStateChange,
);
