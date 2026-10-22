# app/

O projeto Flutter. Android nativo, `minSdk` 24, layout de celular. Sem web e sem iOS (RNF11).

## Fronteira

O app tem telas, reconhecimento de texto do comprovante, pedido de localização e conversão de fuso para exibição. **Nenhuma regra de dinheiro.**

Toda mutação é uma chamada RPC a uma função do banco. Leitura é consulta direta, filtrada pela política de linha. Se uma tela parecer precisar de um `insert` ou `update` numa tabela do rateio, falta uma função no banco.

## Estrutura

- `lib/core/` — cliente Supabase, cliente Google, tema, rotas, fuso.
- `lib/core/widgets/` — peças do design system que as telas repetem (campo, código de seis casas, botão primário, avisos, barra interna). Cor e texto vêm do tema (`Theme.of`, `VoleiCores`), nunca de hex solto.
- `lib/dados/` — modelos e repositórios, um por agregado, chamando as funções.
- `lib/features/` — `auth`, `feed`, `jogo`, `grupo`, `cobranca`, `comprovante`, `perfil`, `avisos`.

## Convenções

- Estado com `flutter_riverpod`.
- Os pacotes permitidos são a lista fechada de `docs/stack.md`, todos gratuitos. Pacote novo precisa ser justificado por custo e tamanho antes de entrar.
- Valor em centavos só vira texto na borda de exibição. Nunca armazene nem calcule em `double`.
- Hora exibida converte de UTC para horário de Brasília na apresentação, mas a decisão de prazo é sempre do servidor: não compare prazo com o relógio do aparelho (RN02).
- Comprima a imagem do comprovante para algo em torno de 200 KB antes do upload.
- Arquivo privado se abre só por URL assinada de validade curta, nunca por link público (RNF02).
- O app lê o comprovante e envia os campos lidos; quem classifica é o servidor (RN09).
