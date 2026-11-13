import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_code.dart';
import '../../../core/errors/error_mapper.dart';

/// Base dos controllers de formulário (docs/arquitetura-app.md, seção 5): o
/// estado é o da submissão, e cada ação devolve o erro, ou nulo no sucesso,
/// para a tela decidir se ele vai para o campo ou para o `SnackBar`.
///
/// O `build` é síncrono de propósito: assim o controller nasce em `AsyncData`.
/// Um `build` assíncrono começa em `AsyncLoading`, e a tela, que desabilita os
/// campos enquanto está ocupada, perdia o autofocus e a primeira digitação.
abstract class SubmitController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  bool get busy => state.isLoading;

  Future<AppException?> submit(Future<void> Function() action) async {
    state = const AsyncLoading();
    try {
      await action();
      if (ref.mounted) state = const AsyncData(null);
      return null;
    } catch (error, stack) {
      final failure = toAppException(error);
      if (ref.mounted) state = AsyncError(failure, stack);
      return failure;
    }
  }
}

extension AppExceptionCode on AppException? {
  bool hasCode(ErrorCode code) => this?.code == code;
}
