# VoleiIn

Aplicativo Android em Flutter que substitui a organização de jogos de vôlei feita hoje em grupos de WhatsApp: marca o jogo, controla quem confirmou com lista de espera e registra o rateio da quadra. O pagamento acontece fora da plataforma, por Pix direto a quem pagou a quadra; o sistema apenas registra quem deve, quanto e se já pagou.

## Fonte de verdade

Os três documentos de `docs/` estão fechados. Leia o que for relevante antes de implementar.

- `docs/prd.md` — **normativo**: requisitos (RF01–RF40), regras de negócio (RN01–RN30), requisitos não funcionais (RNF01–RNF12), decisões tomadas e o que ficou fora do MVP. Em qualquer divergência, o PRD vence.
- `docs/modelo-de-dados.md` — as treze entidades, com diagrama, chaves estrangeiras, unicidades, catálogo de enums e as invariantes que o diagrama não expressa.
- `docs/stack.md` — onde cada regra mora, as funções previstas, a estrutura de pastas e a ordem de implementação.

IMPORTANT: se uma regra parecer ausente, ambígua ou contraditória, pergunte. Não invente regra, campo, enum nem entidade que não esteja nos documentos — lacuna aqui é decisão de produto, não de código.

## Arquitetura em três peças

Não existe servidor de aplicação. O sistema é:

- **Postgres do Supabase** — funções plpgsql com todas as regras, política de linha para leitura, e `pg_cron` rodando uma varredura por minuto para encerramento, vencimento, janela de falta e descarte de comprovante.
- **Uma Edge Function** — o único ponto que fala com serviço externo, acionada por `pg_net` para enviar à FCM.
- **App Flutter** — telas e leitura do comprovante no aparelho.

Qualquer proposta que acrescente um servidor, um host de cron ou uma fila contraria o desenho (RNF12).

## Regras invioláveis

- **O app nunca escreve nas tabelas do rateio.** Toda mutação passa por função plpgsql chamada por RPC; leitura é consulta direta filtrada por política de linha. É o que mantém cálculo, hora de regra e transição de estado dentro da transação (RNF08, RNF09, RNF10).
- **Dinheiro é inteiro em centavos**, nunca float: R$ 18,29 é `1829` e R$ 10,50 é `1050`. O valor por vaga é o custo total dividido pelas vagas, arredondado para cima no **centavo**, não no real — 10000 entre 7 vagas dá `1429` (RN01, RN16).
- **Hora de regra é a hora do servidor**, nunca a do aparelho. Grave em UTC e converta para horário de Brasília na borda (RN02, RNF08).
- Todo identificador é UUID. `Pessoa.id` espelha o id de `auth.users`, e a **ausência de chave estrangeira entre as duas é deliberada** — ver `docs/stack.md`, seção Autenticação. Não "corrija" isso.
- `Comprovante.resultado` é calculado no servidor a partir dos campos lidos. O app informa o que leu, nunca o veredito (RN09).
- **Nenhum custo variável por evento.** Tudo roda em plano gratuito. Não proponha serviço pago sem dizer o preço e perguntar antes.
- Não implemente o que está em "Fora do MVP" (`docs/prd.md`): sem gateway de pagamento, sem reserva de quadra, sem cadastro de locais pelo usuário, sem jogo recorrente, sem reputação, sem chat, sem iOS, sem web, sem painel administrativo.

## Idioma

- Identificadores de domínio em português, como no modelo de dados: tabelas `pessoa`, `jogo`, `cobranca`, `participacao`; colunas `custo_total`, `prazo_cancelamento_horas`, `chave_pix_recebedor`; valores de enum `lista_espera`, `cancelamento_tardio`, `comprovante_enviado`.
- Comentários, mensagens de commit e documentação em português.
- Palavras-chave da linguagem e API de biblioteca ficam no original.

## Ordem de trabalho

`docs/stack.md` define dez passos, e cada um fecha antes do seguinte começar. O que já foi entregue e qual é o passo atual estão em `docs/progresso.md`: **leia esse arquivo antes de implementar** e registre nele ao fechar um passo.

Documentação antes de código: não comece a implementar enquanto uma decisão de produto estiver aberta. Feche o documento primeiro, code em outra rodada.

## Comandos

Os comandos do Supabase estão em `supabase/CLAUDE.md`. Os do Flutter rodam a partir de `app/`:

| Comando | O que faz |
| --- | --- |
| `flutter run --dart-define=SUPABASE_URL=http://10.0.2.2:54321 --dart-define=SUPABASE_PUBLISHABLE_KEY=<chave> --dart-define=GOOGLE_WEB_CLIENT_ID=<id>` | Roda no emulador falando com o Supabase local; a chave sai de `supabase status`, `10.0.2.2` é o host visto de dentro do emulador, e o id é o do cliente web do Google, o mesmo `client_id` de `[auth.external.google]` em `supabase/config.toml` |
| `flutter test` | Testes de widget |
| `dart analyze` | Análise estática, com as mesmas regras de `analysis_options.yaml` |

Não use `flutter analyze`: ele fala com o servidor de análise por LSP, e o "Á" de "Área de trabalho" no caminho quebra a mensagem de abertura com `FormatException`. Link simbólico não contorna, porque o Dart resolve o caminho real. O `dart analyze` usa outro protocolo e funciona daqui.

### Celular físico, por depuração sem fio

`SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` e `GOOGLE_WEB_CLIENT_ID` são resolvidos na compilação, não em tempo de execução (ver `app/lib/core/supabase.dart` e `app/lib/core/google.dart`): cada `flutter run` precisa dos três, e o endereço depende da rede em uso no momento, não da máquina. Isso vale tanto trocando de rede (residencial ou da empresa) quanto trocando de máquina (de casa ou da empresa).

Por aparelho e por máquina, uma vez:
1. No celular, Opções do desenvolvedor → Depuração sem fio → parear com código.
2. Na máquina, `adb pair <ip-do-celular>:<porta>` com o código mostrado no celular.

A partir daí, com o celular na mesma rede da máquina, `flutter devices` encontra o aparelho sem cabo e sem parear de novo — a identidade do pareamento é por máquina, então uma máquina nova pede o passo acima de novo.

Por máquina, uma vez: cadastrar o SHA-1 da chave de debug dela num cliente Android do Google Cloud, no projeto VoleiIn, com o pacote `br.com.voleiin`. Sem ele, a entrada pelo Google falha nos builds daquela máquina. O SHA-1 sai de:

```
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android
```

O APK release também assina com a chave de debug de quem o gera (`signingConfig = debug` em `app/android/app/build.gradle.kts`), até a chave própria do passo 10.

A cada troca de rede (inclusive religando o Wi-Fi), o IP da máquina muda e precisa ser pego de novo:

```
hostname -I | awk '{print $1}'
```

A chave pública não muda com a rede — só se o Supabase local for recriado do zero (`supabase status` mostra a atual). O comando completo:

```
flutter run -d <id-do-aparelho-em-'flutter devices'> \
  --dart-define=SUPABASE_URL=http://<ip-da-máquina-agora>:54321 \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<chave-de-supabase-status> \
  --dart-define=GOOGLE_WEB_CLIENT_ID=<client_id-de-auth.external.google-no-config.toml>
```

Pré-requisito em qualquer rede: celular e máquina não podem estar isolados um do outro. Redes residenciais costumam deixar isso livre; redes de empresa costumam isolar ou bloquear porta fora do padrão por política — teste abrindo `http://<ip-da-máquina>:54321` no navegador do celular antes de insistir no `flutter run`. Se não abrir, é a rede, não o app.
