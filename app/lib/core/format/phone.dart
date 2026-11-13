/// Telefone do Brasil: o que a pessoa digita, o E.164 gravado e a exibição.
///
/// O app só aceita números do Brasil: mostra `+55` fixo e a pessoa digita DDD e
/// número, com 10 ou 11 dígitos (docs/modelo-dados.md, 4.1, decisão de
/// 12/11/2026). O formato E.164 é conferido pela constraint do banco.
library;

import 'br_documents.dart';

/// `(86) 99999-1234` → `+5586999991234`. Nulo se não tiver 10 ou 11 dígitos.
String? phoneToE164(String input) {
  final digits = digitsOnly(input);
  if (digits.length != 10 && digits.length != 11) return null;
  return '+55$digits';
}

/// `+5586999991234` → `(86) 99999-1234`; `+558633221234` → `(86) 3322-1234`.
String formatPhoneE164(String e164) {
  final local = nationalDigits(e164);
  if (local.length != 10 && local.length != 11) return e164;
  return formatNationalPhone(local);
}

/// DDD e número de um E.164 do Brasil, sem o `+55`.
String nationalDigits(String e164) {
  final digits = digitsOnly(e164);
  return digits.startsWith('55') ? digits.substring(2) : digits;
}

/// Máscara progressiva `(86) 99999-1234`, usada também enquanto se digita.
String formatNationalPhone(String digits) {
  final d = digitsOnly(digits);
  if (d.isEmpty) return '';
  if (d.length <= 2) return '($d';
  final ddd = d.substring(0, 2);
  final rest = d.substring(2);
  // Com 11 dígitos, o número tem 5 + 4; com até 10, 4 + 4.
  final split = d.length == 11 ? 5 : 4;
  if (rest.length <= split) return '($ddd) $rest';
  return '($ddd) ${rest.substring(0, split)}-${rest.substring(split)}';
}
