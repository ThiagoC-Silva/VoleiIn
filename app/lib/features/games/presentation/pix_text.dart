import '../../../l10n/app_localizations.dart';
import '../../auth/domain/pix_key.dart';

/// Rótulo do tipo da chave (docs/copy.md, 6.6). A mesma tabela da feature
/// `auth`, que esta feature não importa (docs/arquitetura-app.md, seção 2).
String pixTypeLabel(AppLocalizations l10n, PixKeyType type) => switch (type) {
  PixKeyType.cpf => l10n.pixTypeCpf,
  PixKeyType.cnpj => l10n.pixTypeCnpj,
  PixKeyType.email => l10n.pixTypeEmail,
  PixKeyType.phone => l10n.pixTypePhone,
  PixKeyType.random => l10n.pixTypeRandom,
};
