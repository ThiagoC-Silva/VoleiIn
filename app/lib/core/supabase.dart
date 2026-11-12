import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Cliente único do Supabase, iniciado no `main`.
final supabaseProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);
