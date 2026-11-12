import 'package:flutter_test/flutter_test.dart';
import 'package:voleiin/features/auth/domain/pix_key.dart';

/// Cenários U05 e U06 de docs/testes-referencia.md, seção 10.4.
void main() {
  group('U05: chave Pix para exibição', () {
    test('CPF', () {
      expect(formatPixKey(PixKeyType.cpf, '52998224725'), '529.982.247-25');
    });

    test('CNPJ', () {
      expect(
        formatPixKey(PixKeyType.cnpj, '11222333000181'),
        '11.222.333/0001-81',
      );
    });

    test('telefone', () {
      expect(
        formatPixKey(PixKeyType.phone, '+5586999991234'),
        '(86) 99999-1234',
      );
    });
  });

  group('U06: normalização da chave', () {
    test('e-mail sem espaços nas pontas e em minúsculas', () {
      expect(
        normalizePixKey(PixKeyType.email, ' Ana@Exemplo.com '),
        'ana@exemplo.com',
      );
    });

    test('chave aleatória em minúsculas', () {
      expect(
        normalizePixKey(
          PixKeyType.random,
          '123E4567-E89B-12D3-A456-426614174000',
        ),
        '123e4567-e89b-12d3-a456-426614174000',
      );
    });
  });
}
