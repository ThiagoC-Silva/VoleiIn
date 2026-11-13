// Telefone brasileiro: DDD e número, com 10 (fixo) ou 11 (celular) dígitos,
// gravado em E.164 com o `+55` (docs/ui/telas.md, 5.8 e 5.9).
import 'documents.dart';

/// `(86) 99999-1234` → `+5586999991234`. Nulo se não tiver 10 ou 11 dígitos.
String? phoneToE164(String typed) {
  final digits = digitsOnly(typed);
  if (digits.length != 10 && digits.length != 11) return null;
  return '+55$digits';
}

/// `+5586999991234` → `(86) 99999-1234`. Outro país fica como veio.
String formatPhone(String e164) {
  if (!e164.startsWith('+55')) return e164;
  return formatPhoneDigits(e164.substring(3));
}

/// Máscara do número sem o `+55`, parcial enquanto se digita:
/// `(86) 3322-1234` com 10 dígitos e `(86) 99999-1234` com 11.
String formatPhoneDigits(String text) {
  final d = digitsOnly(text);
  if (d.isEmpty) return '';
  if (d.length <= 2) return '($d';
  final area = d.substring(0, 2);
  final number = d.substring(2);
  // Até 10 dígitos, o hífen fica depois do quarto número; com 11, do quinto.
  final split = d.length <= 10 ? 4 : 5;
  if (number.length <= split) return '($area) $number';
  return '($area) ${number.substring(0, split)}-${number.substring(split)}';
}
