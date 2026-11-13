import 'package:flutter_test/flutter_test.dart';
import 'package:voleiin/core/format/documents.dart';

/// Cenários U01 e U02 de docs/testes-referencia.md, seção 10.4.
/// A mesma regra do banco (X01 a X06).
void main() {
  group('U01: validação de CPF', () {
    test('aceita o CPF válido, só com dígitos', () {
      expect(isValidCpf('52998224725'), isTrue);
    });

    test('aceita o CPF válido, com a máscara', () {
      expect(isValidCpf('529.982.247-25'), isTrue);
    });

    test('recusa o CPF com o último dígito trocado', () {
      expect(isValidCpf('52998224724'), isFalse);
    });

    test('recusa a sequência de um dígito só, embora passe na conta', () {
      expect(isValidCpf('11111111111'), isFalse);
    });
  });

  group('U02: validação de CNPJ', () {
    test('aceita o CNPJ válido, só com dígitos', () {
      expect(isValidCnpj('11222333000181'), isTrue);
    });

    test('aceita o CNPJ válido, com a máscara', () {
      expect(isValidCnpj('11.222.333/0001-81'), isTrue);
    });

    test('recusa o CNPJ com o último dígito trocado', () {
      expect(isValidCnpj('11222333000180'), isFalse);
    });

    test('recusa a sequência de um dígito só', () {
      expect(isValidCnpj('00000000000000'), isFalse);
    });

    // Formato alfanumérico da Receita Federal (modelo-dados.md, 4.1).
    test('aceita o CNPJ alfanumérico válido', () {
      expect(isValidCnpj('12ABC34501DE35'), isTrue);
    });

    test('aceita o CNPJ alfanumérico com a máscara', () {
      expect(isValidCnpj('12.ABC.345/01DE-35'), isTrue);
    });

    test('aceita o CNPJ alfanumérico digitado em minúsculas', () {
      expect(isValidCnpj('12abc34501de35'), isTrue);
    });

    test('recusa o CNPJ alfanumérico com o último dígito trocado', () {
      expect(isValidCnpj('12ABC34501DE36'), isFalse);
    });

    test('recusa letra no dígito verificador', () {
      expect(isValidCnpj('12ABC34501DEA5'), isFalse);
    });
  });
}
