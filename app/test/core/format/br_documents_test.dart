import 'package:flutter_test/flutter_test.dart';
import 'package:voleiin/core/format/br_documents.dart';

/// Cenários U01 e U02 de docs/testes-referencia.md, seção 10.4. A mesma regra
/// do banco (X01 a X06): o app só avisa no campo, quem decide é a constraint.
void main() {
  test('U01: validação de CPF', () {
    expect(isValidCpf('52998224725'), isTrue);
    expect(isValidCpf('529.982.247-25'), isTrue);
    expect(isValidCpf('52998224724'), isFalse);
    expect(isValidCpf('11111111111'), isFalse);
  });

  test('U02: validação de CNPJ', () {
    expect(isValidCnpj('11222333000181'), isTrue);
    expect(isValidCnpj('11.222.333/0001-81'), isTrue);
    expect(isValidCnpj('11222333000180'), isFalse);
    expect(isValidCnpj('00000000000000'), isFalse);
  });

  test('CPF e CNPJ com tamanho errado são inválidos', () {
    expect(isValidCpf('5299822472'), isFalse);
    expect(isValidCnpj('1122233300018'), isFalse);
    expect(isValidCpf(''), isFalse);
  });
}
