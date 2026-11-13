import 'package:json_annotation/json_annotation.dart';

import '../../../core/format/br_documents.dart';
import '../../../core/format/phone.dart';

/// Tipo da chave Pix (enum `pix_key_type`, docs/modelo-dados.md, seção 3).
enum PixKeyType {
  @JsonValue('cpf')
  cpf,
  @JsonValue('cnpj')
  cnpj,
  @JsonValue('email')
  email,
  @JsonValue('phone')
  phone,
  @JsonValue('random')
  random,
}

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
final _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);

/// Validação, normalização e exibição da chave por tipo (docs/ui/telas.md, 5.9).
///
/// É formato de entrada, não regra: as constraints do banco decidem
/// (docs/modelo-dados.md, 4.1). O app confere antes só para avisar no campo.
extension PixKeyFormat on PixKeyType {
  /// Valor como o banco grava: CPF e CNPJ só dígitos, e-mail e aleatória em
  /// minúsculas, telefone em E.164.
  String normalize(String input) {
    final trimmed = input.trim();
    return switch (this) {
      PixKeyType.cpf || PixKeyType.cnpj => digitsOnly(trimmed),
      PixKeyType.email || PixKeyType.random => trimmed.toLowerCase(),
      PixKeyType.phone => phoneToE164(trimmed) ?? trimmed,
    };
  }

  /// O que o app confere antes de enviar.
  bool isValid(String input) {
    final value = normalize(input);
    return switch (this) {
      PixKeyType.cpf => isValidCpf(value),
      PixKeyType.cnpj => isValidCnpj(value),
      PixKeyType.email => _emailPattern.hasMatch(value),
      PixKeyType.phone => phoneToE164(input.trim()) != null,
      PixKeyType.random => _uuidPattern.hasMatch(value),
    };
  }

  /// Chave gravada, formatada para exibição.
  String format(String stored) => switch (this) {
    PixKeyType.cpf => formatCpf(stored),
    PixKeyType.cnpj => formatCnpj(stored),
    PixKeyType.phone => formatPhoneE164(stored),
    PixKeyType.email || PixKeyType.random => stored,
  };
}
