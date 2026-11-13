import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_code.dart';
import '../../../core/errors/error_mapper.dart';

/// Base dos controllers de formulário (docs/arquitetura-app.md, seção 5): o
/// estado é o da submissão, e cada ação devolve o erro, ou nulo no sucesso,
/// para a tela decidir se ele vai para o campo ou para o `SnackBar`.
abstract class SubmitController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

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
