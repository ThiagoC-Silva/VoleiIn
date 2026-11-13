import 'package:flutter_test/flutter_test.dart';
import 'package:voleiin/features/auth/domain/pix_key_type.dart';

/// Cenários U05 e U06 de docs/testes-referencia.md, seção 10.4, e as regras da
/// tabela da chave em docs/ui/telas.md, 5.9.
void main() {
  test('U05: chave Pix para exibição', () {
    expect(PixKeyType.cpf.format('52998224725'), '529.982.247-25');
    expect(PixKeyType.cnpj.format('11222333000181'), '11.222.333/0001-81');
    expect(PixKeyType.phone.format('+5586999991234'), '(86) 99999-1234');
  });

  test('U06: normalização da chave', () {
    expect(PixKeyType.email.normalize(' Ana@Exemplo.com '), 'ana@exemplo.com');
    expect(
      PixKeyType.random.normalize('123E4567-E89B-12D3-A456-426614174000'),
      '123e4567-e89b-12d3-a456-426614174000',
    );
    expect(PixKeyType.cpf.normalize('529.982.247-25'), '52998224725');
    expect(PixKeyType.phone.normalize('(86) 99999-1234'), '+5586999991234');
  });

  test('validação por tipo, como na tabela do telas.md 5.9', () {
    expect(PixKeyType.cpf.isValid('529.982.247-25'), isTrue);
    expect(PixKeyType.cpf.isValid('52998224724'), isFalse);
    expect(PixKeyType.cnpj.isValid('11222333000181'), isTrue);
    expect(PixKeyType.email.isValid('ana@exemplo.com'), isTrue);
    expect(PixKeyType.email.isValid('ana@exemplo'), isFalse);
    expect(PixKeyType.phone.isValid('(86) 99999-1234'), isTrue);
    expect(PixKeyType.phone.isValid('(86) 9999-123'), isFalse);
    expect(
      PixKeyType.random.isValid('123e4567-e89b-12d3-a456-426614174000'),
      isTrue,
    );
    expect(PixKeyType.random.isValid('123e4567'), isFalse);
  });
}
