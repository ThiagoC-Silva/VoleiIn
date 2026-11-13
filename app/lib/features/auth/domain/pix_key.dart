import 'package:json_annotation/json_annotation.dart';

import '../../../core/format/documents.dart';
import '../../../core/format/phone.dart';

/// Enum `pix_key_type` do banco (docs/modelo-dados.md, seção 3).
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
  random;

  /// Valor do banco.
  String get value => name;
}

final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);

/// A chave como ela é gravada (docs/ui/telas.md, 5.9): CPF só com os dígitos,
/// CNPJ sem pontuação e em maiúsculas, e-mail e aleatória sem espaços e em
/// minúsculas, telefone em E.164.
/// Telefone com outro número de dígitos fica só com os dígitos, e a conferência
/// recusa.
String normalizePixKey(PixKeyType type, String typed) => switch (type) {
  PixKeyType.cpf => digitsOnly(typed),
  PixKeyType.cnpj => normalizeCnpj(typed),
  PixKeyType.email || PixKeyType.random => typed.trim().toLowerCase(),
  PixKeyType.phone => phoneToE164(typed) ?? digitsOnly(typed),
};

/// Se a chave digitada vale para o tipo. É a mesma regra das constraints do
/// banco, que decidem de verdade.
bool isValidPixKey(PixKeyType type, String typed) {
  final key = normalizePixKey(type, typed);
  return switch (type) {
    PixKeyType.cpf => isValidCpf(key),
    PixKeyType.cnpj => isValidCnpj(key),
    PixKeyType.email => _email.hasMatch(key),
    PixKeyType.phone => phoneToE164(typed) != null,
    PixKeyType.random => _uuid.hasMatch(key),
  };
}

/// A chave gravada, no formato de exibição (U05).
String formatPixKey(PixKeyType type, String key) => switch (type) {
  PixKeyType.cpf => formatCpf(key),
  PixKeyType.cnpj => formatCnpj(key),
  PixKeyType.phone => formatPhone(key),
  PixKeyType.email || PixKeyType.random => key,
};

/// A chave gravada, no formato do campo de edição: o telefone fica sem o
/// `+55`, que é o prefixo fixo do campo.
String pixKeyForField(PixKeyType type, String key) => switch (type) {
  PixKeyType.phone =>
    key.startsWith('+55') ? formatPhoneDigits(key.substring(3)) : key,
  _ => formatPixKey(type, key),
};
