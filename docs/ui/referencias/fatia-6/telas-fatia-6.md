# VoleiIn: pagamento, comprovantes e exclusão de conta

## Sobre o app

O VoleiIn é um app Android, em português do Brasil, para grupos de vôlei. Ele organiza jogos e listas de presença, calcula a divisão do valor da quadra e acompanha os pagamentos por Pix entre os participantes. O app não processa pagamentos: a pessoa paga no app do banco e volta para enviar o comprovante.

Este documento descreve as telas de **pagamento**: ver o valor a pagar com a chave Pix, enviar o comprovante, conferir o comprovante de alguém, marcar um valor como pago à mão, e **excluir a conta**.

## Como o pagamento funciona

- Depois que o jogo é concluído, cada pessoa tem um **valor a pagar** ao **recebedor** do jogo. O valor começa **Pendente**.
- A pessoa copia a chave Pix do recebedor, paga no banco e envia o **comprovante**, em imagem ou PDF.
- O app **lê o comprovante** em até 30 segundos. Se o valor, quem recebeu, a data e o código do Pix conferirem, o valor fica **Pago** na hora. Se algo não conferir ou não puder ser lido, o valor fica **Em análise**, e o recebedor decide.
- O recebedor **aprova** (o valor fica Pago, e não pode voltar) ou **recusa**, escrevendo o motivo (o valor volta a Pendente, e a pessoa pode enviar outro).
- Se o comprovante **já foi usado em outro pagamento**, o envio é recusado na hora.
- O app lê até **3 comprovantes** por valor. Depois disso, o envio vai direto para o recebedor.
- O recebedor também pode **marcar como pago** sem comprovante, e **reverter** o que marcou assim.
- O arquivo é apagado 30 dias depois da decisão. O registro fica.
- Só quem pagou e quem recebe veem o comprovante. Os admins do jogo, não.

## Pessoas e jogo dos exemplos

- **Vôlei de Quinta**, o grupo. **Ana Souza Lima** (aparece como **Ana**) é a recebedora, com a chave **CPF 529.982.247-25**. **Fábio**, **Brunão** e **Carlinha** devem a ela.
- **Jogo:** **Quadra do Sesc**, **qui, 19/11**, das **20:00 às 22:00**. A parte de cada um é **R$ 20,84**.
- **Fábio** deve R$ 20,84 (Parte do jogo). **Carlinha** deve R$ 20,84 (Multa por cancelamento).

## Regras gerais

As regras das telas anteriores continuam: só modo escuro, largura de 360 dp, tom informal com "você", botões com verbo no infinitivo, área de toque de 48 × 48 dp, fonte do sistema em 150% sem nada cortado, um botão principal por tela.

**Fontes:** Montserrat nos títulos e nomes; **Bebas Neue só nos números**; Roboto no resto. O código do Pix diferencia letras e números parecidos: não use Bebas Neue nele.

**Cores dos blocos grandes**, sempre com texto azul-marinho escuro (`#192853`):

| Cor | Hex | Significa |
|-----|-----|-----------|
| Coral | `#FF8F6B` | Valor Pendente a pagar |
| Azul-claro | `#8EC5FF` | Valor Em análise |
| Verde-água | `#7CDCC8` | Valor Pago, a receber |
| Azul-acinzentado | `surfaceHigh` | Valor Isento (texto claro) |

**Selos do valor:** **Pendente** (amarelo), **Em análise** (azul, com ampulheta), **Pago** (verde), **Isento** (neutro). **Selos do comprovante:** **Em análise** (azul, com ampulheta), **Aprovado** (verde, com visto), **Recusado** (vermelho, com xis). **Selos da conferência:** **Confere** (verde), **Não confere** (vermelho), **Não lido** (neutro).

**Componentes novos:**

- **Miniatura de arquivo:** a imagem com cantos arredondados, ou um ícone de PDF com o nome e o tamanho.
- **Linha de conferência:** o rótulo e o selo na primeira linha; embaixo, "Esperado: ..." e "Lido: ...".
- **Linha de comprovante:** "Enviado qui, 19/11 às 22:20", o selo e, embaixo, a observação.

## Fluxo entre as telas

1. Na aba **Cobranças**, tocar numa linha de **A pagar** abre o **Valor a pagar**. O botão **Pagar** do Rateio também.
2. **Enviar comprovante** abre uma folha com quatro passos: escolher, conferir, lendo e resultado.
3. Na aba **Cobranças**, o recebedor vê **Para conferir**. Tocar numa linha abre o **Comprovante**.
4. No **Rateio**, o recebedor toca numa pessoa e marca como pago ou reverte.
5. No **Perfil**, **Excluir conta**.

---

## 1. Valor a pagar, Pendente (visto pelo Fábio)

A barra inferior aparece, com **Cobranças** ativo.

1. **Topo coral** com o botão de voltar: pílula **Vôlei de Quinta**, "qui, 19/11 · Quadra do Sesc", o valor **R$ 20,84** grande em Bebas Neue, "Parte do jogo" e o selo **Pendente**.
2. Bloco **Pagar para**: avatar e nome **Ana**, "CPF · 529.982.247-25", o botão de texto **Copiar chave** e a dica "Pague o valor exato. Assim o app confere o comprovante sozinho."
3. **Comprovantes**, com dois exemplos, do mais novo para o mais antigo:
   - "Enviado sex, 20/11 às 09:10", selo **Recusado**, e embaixo a observação entre aspas: "O valor está errado, faltam 4 centavos.";
   - "Enviado qui, 19/11 às 22:30", selo **Recusado**, e "Recusado: já foi usado em outro pagamento."
4. No pé, fixo, o botão principal **Enviar comprovante**.

**Outros estados**, que seguem o mesmo desenho:

- **Em análise:** topo azul-claro, o bloco da chave continua, mais o aviso em linha "Ana vai conferir o seu comprovante.", o comprovante **Em análise** na lista, e sem botão no pé.
- **Pago:** topo verde-água, sem o bloco da chave; "Pago por comprovante em qui, 19/11." ou "Ana marcou como pago em sex, 20/11."
- **Isento:** topo azul-acinzentado, com o motivo ("Isentado por um admin").

## 2. Enviar comprovante (folha)

**Passo 1, escolher:** título **Enviar comprovante**; "Envie a imagem ou o PDF do Pix. O app lê o comprovante e, se tudo conferir, o valor fica Pago na hora."; duas opções com ícone: **Escolher imagem** e **Escolher PDF**. Quando as 3 leituras acabaram, um aviso em linha: "O app já leu 3 comprovantes deste valor. O próximo vai direto para Ana conferir."

**Passo 2, conferir:** o mesmo título; a miniatura da imagem (grande, sem cortar o comprovante); o botão principal **Enviar** e o botão de texto **Escolher outro**. Com PDF, no lugar da miniatura, o ícone de PDF, "comprovante.pdf" e "184 KB".

**Passo 3, lendo:** a miniatura, o indicador de carregando e "Lendo o comprovante. Leva até 30 segundos." Sem botão: a folha não fecha.

**Passo 4, resultado**, três versões:

- **Aprovado:** ícone grande verde-água, "Comprovante aprovado. O valor está Pago." e o botão principal **Pronto**.
- **Em análise:** ícone de ampulheta azul, "O comprovante foi para Ana conferir." e o botão principal **Pronto**.
- **Repetido:** ícone vermelho, "Este comprovante já foi usado em outro pagamento.", o botão principal **Enviar outro** e o de contorno **Fechar**.

## 3. Comprovante, visto pela Ana (para conferir)

A barra inferior aparece, com **Cobranças** ativo. A tela rola.

1. Barra interna com voltar e o título **Comprovante**.
2. Avatar e nome **Fábio**, "qui, 19/11 · Quadra do Sesc", **R$ 20,84** e o selo **Em análise**.
3. A **imagem do comprovante**, grande, que abre em tela cheia ao tocar.
4. **Conferência**, com a frase "O app leu o comprovante. Confira com o arquivo antes de decidir." e quatro linhas:
   - **Valor**, selo **Não confere**: "Esperado: R$ 20,84", "Lido: R$ 20,80";
   - **Quem recebeu**, selo **Confere**: "Esperado: Ana Souza Lima", "Lido: ANA SOUZA LIMA";
   - **Data e hora**, selo **Não lido**: "A partir de qui, 19/11 às 20:00";
   - **Código do Pix**, selo **Confere**: "Lido: E18236120202611200115S0123456789" (pode quebrar em duas linhas).
5. No pé, fixos, o botão principal **Aprovar** e o destrutivo de contorno **Recusar**.

**Sem leitura:** no lugar das linhas, uma frase: "O app não conseguiu ler este comprovante."

**Recusar** abre uma folha: título **Recusar o comprovante**, "O valor volta para Pendente, e Fábio lê a sua observação.", o campo **Observação** com contador (0/200) e o botão destrutivo sólido **Recusar**. **Aprovar** pede confirmação em tom normal: "Aprovar o comprovante?", "O valor de R$ 20,84 fica Pago e não pode voltar."

## 4. Comprovante, visto pelo Fábio (recusado)

1. O mesmo título. "Para Ana", "qui, 19/11 · Quadra do Sesc", **R$ 20,84** e o selo **Recusado**.
2. O arquivo. Com PDF, o botão de contorno **Abrir PDF**. Depois de 30 dias, a frase "O arquivo foi apagado em dom, 20/12."
3. "Recusado por Ana em sex, 20/11." e a observação entre aspas.
4. Sem conferência e sem botões.

## 5. Cobranças, com Para conferir (vista pela Ana)

A tela `charges.png`, com uma seção nova entre os atalhos e **A pagar**: título **Para conferir · 2** e duas linhas, com avatar, nome, "qui, 19/11 · Quadra do Sesc", R$ 20,84 e o selo **Em análise**: **Fábio** e **Carlinha**.

## 6. Rateio, folha da pessoa (vista pela Ana)

A folha de `gameSplit-isentar.png`, com o avatar, o nome e "Multa por cancelamento · R$ 20,84 · Pendente" e as opções:

- **Marcar como pago**, com "Sem comprovante, se você já recebeu";
- **Isentar multa**, com "O valor deixa de ser cobrado";
- **Ver perfil**.

Num valor **Pago** à mão, a opção é **Reverter pagamento**, com "O valor volta para Pendente". Num valor **Em análise**, **Conferir comprovante**. As confirmações seguem as anteriores: "Carlinha já pagou R$ 20,84?", "O valor fica Pago. Se precisar, você pode reverter."; "Reverter o pagamento de Fábio?", "O valor volta para Pendente, e Fábio é avisado."

## 7. Excluir conta

Cobre a barra inferior. Aberta por uma linha **Excluir conta**, em tom destrutivo, no fim do Perfil, depois de **Sair**.

1. Barra interna com voltar e o título **Excluir conta**.
2. **O que é apagado**: "Seu nome, apelido, foto, telefone, chave Pix e e-mail. Você sai dos grupos, das listas e das esperas."
3. **O que fica**: "Os jogos, os valores e os comprovantes continuam no histórico dos outros, com o nome Usuário removido."
4. "Não dá para desfazer."
5. No pé, o botão destrutivo de contorno **Excluir minha conta**. A confirmação é a destrutiva de sempre: "Excluir a sua conta?", "Seus dados são apagados agora e não podem voltar.", **Excluir** e **Voltar**.

**Bloqueada:** acima das listas, um bloco de aviso com o título **Antes de excluir, resolva:** e uma linha com seta por motivo. No exemplo: "Você tem valores a pagar.", "Você é o último admin de um grupo. Indique outro admin ou exclua o grupo." e "Você está num jogo que ainda não foi concluído. Espere a conclusão."

## Imagens a produzir

| Arquivo | Tela | Etapa | Status |
|---------|------|-------|--------|
| `charge.png` | 1. Valor a pagar Pendente, com os dois comprovantes e o botão | A e B | Obrigatório |
| `charge-analise.png` | 1. Valor a pagar Em análise | B | Opcional |
| `charge-pago.png` | 1. Valor a pagar Pago | A | Opcional |
| `gameSplit-marcarPago.png` | 6. Folha da pessoa no Rateio | A | Opcional: segue `gameSplit-isentar.png` |
| `charge-enviar1.png` | 2. Passo 1, escolher | B | Obrigatório |
| `charge-enviar2.png` | 2. Passo 2, conferir, com imagem | B | Obrigatório |
| `charge-enviar3.png` | 2. Passo 3, lendo | B | Opcional |
| `charge-enviar4.png` | 2. Passo 4, um dos três resultados | B | Obrigatório |
| `receipt.png` | 3. Comprovante visto pela Ana, com a conferência | B | Obrigatório |
| `receipt-recusar.png` | 3. Folha de recusar | B | Opcional |
| `receipt-pagador.png` | 4. Comprovante recusado, visto pelo Fábio | B | Obrigatório |
| `charges-conferir.png` | 5. Cobranças com Para conferir | B | Obrigatório |
| `profileDelete.png` | 7. Excluir conta | C | Obrigatório |
| `profileDelete-bloqueada.png` | 7. Excluir conta bloqueada | C | Obrigatório |

Não é preciso desenhar os estados comuns (carregando, erro, sem internet, não encontrado, *snackbar*, erro de campo), salvo se quiser uma aparência diferente. Na etapa A, `charge.png` é implementada sem a lista de comprovantes e sem o botão do pé.
