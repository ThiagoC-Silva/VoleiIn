# Stack — VoleiIn

Oct 16, 2026 · @Thiago

Como o MVP descrito no [PRD](prd.md) é construído. O PRD diz o que o produto faz e o [modelo de dados](modelo-de-dados.md) diz o que ele guarda; este documento diz onde cada coisa roda. A referência normativa continua sendo o PRD: quando houver divergência, ele vence.

A restrição que organiza tudo aqui é custo. O piloto cabe inteiro em planos gratuitos, sem nenhum custo variável por evento, e é isso que justifica cada escolha abaixo — inclusive as que trocam conforto por preço, como não ter iOS e não ter tela de administração.

## Escolhas

| Camada | Escolha | Custo |
| --- | --- | --- |
| App | Flutter, Android nativo, `minSdk` 23, layout de celular, `applicationId` `br.com.voleiin` | R$ 0 |
| Distribuição | Firebase App Distribution, convite por e-mail e build por link | R$ 0 |
| Banco e API | Postgres do Supabase, com política de linha; o app consulta direto, sem servidor no meio | R$ 0 até 500 MB |
| Autenticação | Supabase Auth, código de seis dígitos por e-mail (`signInWithOtp`) | R$ 0 até 50 mil contas ativas por mês |
| Envio de e-mail | Brevo como SMTP próprio do Supabase Auth, 300 mensagens por dia | R$ 0 |
| Push | Firebase Cloud Messaging, pelo pacote `firebase_messaging` | R$ 0, sem teto |
| Arquivos | Supabase Storage, espaço privado e URL assinada curta | R$ 0 até 1 GB |
| Leitura do comprovante | `google_mlkit_text_recognition`, reconhecimento no próprio aparelho | R$ 0, sem rede |
| Regras de negócio | Funções plpgsql no Postgres, chamadas por RPC | R$ 0 |
| Rotinas periódicas | `pg_cron` dentro do banco, uma varredura por minuto | R$ 0 |
| Disparo de push | `pg_net` chamando uma Edge Function que fala com a FCM | R$ 0 até 500 mil chamadas por mês |
| Página de convite | Arquivo estático no GitHub Pages | R$ 0 |
| Proximidade de locais | `geolocator` no app, distância calculada em SQL | R$ 0, sem API de mapa |
| Base de locais | Supabase Studio, direto nas tabelas (RN18) | R$ 0 |

Nenhuma linha tem custo por evento: o que cresce com o uso é espaço e tráfego, não conta. O único gasto previsto é de US$ 25, uma única vez, se a distribuição direta do APK for barrada e o caminho virar o teste interno da Play.

Se o Brevo exigir aprovação de conta antes de liberar o SMTP, a alternativa é o Resend: 3.000 mensagens por mês com teto de 100 por dia, pedindo cartão sem cobrar. Qualquer um dos dois entra como SMTP próprio do Supabase Auth, porque o servidor que vem embutido no plano gratuito serve só para teste.

## Onde cada regra mora

O desenho tem uma regra de corte: **o app nunca escreve nas tabelas do rateio**. Toda mutação passa por uma função no banco; a leitura vai por consulta direta, filtrada por política de linha. É o que mantém cálculo, hora de regra e transição de estado em um só lugar, dentro da transação, como RNF08, RNF09 e RNF10 exigem.

| Camada | O que vive lá |
| --- | --- |
| Funções plpgsql (RPC) | Todo cálculo e toda transição de estado: rateio e arredondamento (RN01, RN16), prazo e multa (RN02, RN03), fila e disputa de vaga (RN08, RNF09), reconfirmação (RN25), substituição e isenção automática (RN05), edição e recálculo (RN20), ciclo do jogo (RN17, RN23), falta (RN04), baixa e isenção manual (RN07, RN13), triagem e unicidade do comprovante (RN09, RN10), regras e membros do grupo (RN11, RN30), convite (RN22), exclusão de conta (RN27) |
| Política de linha | Quem lê o quê, na matriz da seção seguinte: cobrança e comprovante só para devedor e credor (RN19, RNF02), jogo para membros do grupo e participantes, aviso só para o destinatário, Local e Quadra somente leitura para todo mundo (RN18). Também as três escritas diretas fora do rateio |
| `pg_cron`, uma vez por minuto | Encerramento do jogo (RN17), vencimento da cobrança (RN07), fim da janela de falta (RN04), descarte de comprovante por retenção (RNF03) e remoção de token de push já rejeitado |
| Edge Function | Único ponto que fala com serviço externo: o envio para a FCM, acionado por `pg_net` a partir de um gatilho em Notificacao |
| App Flutter | Telas, reconhecimento de texto do comprovante, pedido de localização, conversão de fuso para exibição. Nenhuma regra de dinheiro |

As funções previstas, uma por operação que muda estado:

| Função | Regras que ela carrega |
| --- | --- |
| `criar_jogo`, `duplicar_jogo` | RN15 (quadra e funcionamento), RN24 (chave do recebedor), RN01 e RN16 (preço por vaga), RN28 |
| `confirmar_presenca` | RNF09 (trava e contagem), RN08 (fila), RN25 (reconfirmação), RN07 (nascimento da cobrança) |
| `cancelar_presenca` | RN02 e RN03 (prazo e multa), RN05 (isenção do substituído), RN08 (promoção da fila) |
| `editar_jogo` | RN20 (janelas de edição), RN01 (recálculo), RN06, RN11 e RN29 (avisos) |
| `cancelar_jogo`, `encerrar_jogo` | RN23, RN17, RN07 (liberação do pagamento) |
| `marcar_falta` | RN04, RN13 (quem pode) |
| `dar_baixa`, `isentar_cobranca` | RN07 (congelamento), RN13 (só o credor) |
| `enviar_comprovante` | RN09 (classificação no servidor), RN10 (unicidade do identificador) |
| `apagar_comprovante` | RF37, RN19 (só o devedor, só depois da baixa; esvazia `arquivo_url` e preserva a linha) |
| `criar_grupo` | RF03, RN12 (padrões do grupo); quem cria entra como admin (RN13, RN30) |
| `editar_grupo` | RF06, RN11 (vale de imediato nos jogos abertos, aviso aos confirmados), RN13 (só admins) |
| `promover_admin` | RF31, RN13 (só quem criou o grupo), RN29 (aviso) |
| `remover_membro`, `sair_grupo` | RF29, RF30, RN30 (participações e cobranças ficam; quem criou só sai depois de promover outro admin), RN13 (remoção só por admin), RN29 (aviso ao removido) |
| `gerar_convite`, `revogar_convite` | RF09, RF32, RN22 (convite de jogo expira no início; o de grupo, só por revogação), RN13 (grupo: só admins; jogo: qualquer confirmado) |
| `aplicar_convite` | RF04, RN22 (expiração e revogação), RN13 |
| `registrar_dispositivo` | RF38, RN29; token já registrado por outra conta passa a quem registra agora (seção Política de linha) |
| `listar_participantes` | RN26 (a marca de débito vencido só aparece para criador, recebedor e admins) |
| `excluir_conta` | RN27 (bloqueio por pendência, anonimização, remoção do usuário) |
| `rotinas_minuto` | O que a linha de `pg_cron` acima descreve |

## Política de linha

Toda tabela tem política de linha, e o papel `anon` não lê nem escreve nada: o app só fala com o banco depois de autenticado. Para `authenticated`, a leitura segue a matriz abaixo. "Ver o jogo" é ser criador, recebedor, membro do grupo do jogo ou ter participação nele, em qualquer status.

| Tabela | Quem lê |
| --- | --- |
| `pessoa` | O próprio, quem divide um grupo com ele e quem está envolvido — participação, criador ou recebedor — num jogo que ele vê. Todas as colunas, inclusive telefone e chave Pix: dentro da turma, é o uso normal delas, e é o que alimenta a lista de recebedores com chave (RN24) |
| `grupo` | Membros, e quem participa de um jogo do grupo sem ser membro, para o selo do feed (RF12) |
| `membro_grupo` | Membros do mesmo grupo (RF05) |
| `convite` | Quem criou, e os admins do grupo no convite de tipo `grupo` (RF32) |
| `local`, `quadra`, `horario_funcionamento` | Todos (RN18) |
| `jogo`, `participacao` | Quem vê o jogo |
| `cobranca`, `comprovante` | Devedor e credor da cobrança (RN19, RNF02) |
| `notificacao`, `dispositivo_push` | O titular |

A regra de corte vale para o rateio. Três escritas ficam de fora dele e vão direto à tabela, cada uma limitada à linha do titular pela política e às colunas pelo privilégio: o próprio perfil em `pessoa` (nome, foto, telefone e chave Pix, RF02), `lida_em` dos próprios avisos em `notificacao` (RF40) e apagar os próprios aparelhos em `dispositivo_push` (RF38). Qualquer outra escrita do app é recusada pelo banco.

Registrar um aparelho não é escrita direta: passa pela `registrar_dispositivo`. O token da FCM pertence à instalação do app, não à pessoa, então duas contas que se revezam no mesmo celular disputam o mesmo token. Se o Bruno sai da conta sem rede e a Carla entra no mesmo aparelho, a linha dele continua lá: um `insert` da Carla bateria na unicidade de `token_fcm` sem que ela enxergue a linha que a bloqueia, e os avisos de cobrança do Bruno seguiriam chegando à tela dela. A função resolve os dois de uma vez: token já registrado passa a quem o registra agora, porque só quem está com o aparelho na mão conhece o token. O app também apaga a própria linha ao sair da conta, como limpeza do caminho normal.

A `listar_participantes` é função, e não consulta com política de linha, porque o que varia não é a linha: é uma coluna, visível a uns e não a outros. Decidir isso em SQL, com o papel de quem chama, sai mais simples que montar duas visões.

## Autenticação

A credencial é o e-mail e vive em `auth.users`, tabela do próprio Supabase Auth; `Pessoa` é só o perfil. Os dois se ligam pelo id: um gatilho cria a linha de `Pessoa` com o mesmo UUID do usuário no primeiro acesso, e nenhuma chave estrangeira amarra as duas.

O nome chega ao gatilho pelos metadados do cadastro, porque `Pessoa.nome` é obrigatório e a tela de entrar só tem o e-mail (RN21). O app pede o código com `signInWithOtp(shouldCreateUser: false)`; se a conta não existe, o serviço responde `otp_disabled`, a tela mostra o campo de nome e repete o pedido com `shouldCreateUser: true` e `data: {'nome': ...}`. O gatilho lê `raw_user_meta_data->>'nome'` sem espaços nas pontas e, vazio, recusa o cadastro inteiro: não existe perfil sem nome nem estado de perfil incompleto. O custo aceito é a tela revelar se um e-mail já tem conta.

A ausência dessa chave é deliberada. A exclusão de conta precisa apagar o usuário — é o que faz a credencial deixar de existir — e **preservar** o perfil anonimizado, porque participações e cobranças de terceiros apontam para ele (RN27). Com chave estrangeira em cascata, apagar o usuário levaria o histórico; sem ela, o perfil sobrevive sozinho, anônimo e sem forma de login. O ganho secundário é que a política de linha compara `id = auth.uid()` direto, sem subconsulta.

O Supabase Auth atende a RNF06 por configuração: código de seis dígitos (`otp_length = 6`), validade de cinco minutos (`otp_expiry = 300`), uso único e limite de envios. O limite por endereço é o intervalo mínimo de 60 segundos entre envios ao mesmo e-mail (`max_frequency`), no máximo 60 por hora; o teto do projeto (`rate_limit.email_sent`) fica abaixo das 300 mensagens por dia do Brevo. Os modelos de e-mail — primeiro acesso, acesso e troca de e-mail — são em português e mostram o código (`{{ .Token }}`), não um link. O produto não implementa geração, hash nem contagem de tentativas.

A RNF07 é atendida pelo par de tokens do serviço. Na troca de e-mail, confirmada nos dois endereços (`double_confirm_changes`), o app chama `signOut(scope: others)`: as outras sessões caem e a do aparelho que confirmou continua. Na exclusão, o `signOut` é global. Os aparelhos de push não dependem do app cooperar: um gatilho na mudança de `email` em `auth.users` apaga todo `dispositivo_push` do titular, e o aparelho que confirmou registra a si mesmo de novo. Como o `email` só muda depois das duas confirmações, o gatilho não dispara em troca pela metade.

As duas funções de gatilho ficam no schema `privado`, na migração `autenticacao`, e não são RPC.

## Estrutura

```
supabase/
  migrations/   criadas com `supabase migration new <nome>`, que prefixa o
                timestamp UTC. Na ordem dos passos: enums, tabelas, indices,
                rls, autenticacao, rpc_grupo, rpc_jogo, rpc_presenca, rpc_cobranca, storage,
                avisos, rotinas_cron, rpc_convite
  seed.sql      locais, quadras e horários do piloto
  functions/enviar-push/
app/            projeto Flutter
  lib/core/     cliente Supabase, tema, rotas, fuso
  lib/dados/    modelos e repositórios, um por agregado, chamando as funções
  lib/features/ auth, feed, jogo, grupo, cobranca, comprovante, perfil, avisos
web-convite/    página estática do GitHub Pages
```

Pacotes do app, todos gratuitos: `supabase_flutter`, `firebase_core`, `firebase_messaging`, `google_mlkit_text_recognition`, `image_picker`, `flutter_image_compress`, `geolocator`, `app_links`, `intl`, `flutter_riverpod`.

O convite tem dois caminhos para a mesma coisa (RN22): um código curto que a pessoa cola na tela de entrar, e um link que a página do GitHub Pages redireciona para o app. O código existe porque é o que funciona quando o link não abre.

## Ordem de implementação

Cada passo fecha antes do seguinte começar.

1. **Schema.** Enums, tabelas, índices e unicidades. Atenção ao índice único de `id_transacao`, que precisa ser parcial: vários comprovantes ilegíveis entram sem identificador e não disputam entre si (RN10).
2. **Política de linha.** Uma política por tabela, mais a negação de escrita em Local, Quadra e HorarioFuncionamento, e a função `listar_participantes`.
3. **Autenticação.** Projeto no Supabase, Brevo como SMTP, código de seis dígitos e cinco minutos, gatilho de criação do perfil, telas de entrar e de trocar o e-mail.
4. **Núcleo financeiro.** As funções de grupo (`criar_grupo`, `editar_grupo`, `promover_admin`, `remover_membro`, `sair_grupo`), de jogo, presença e cobrança, com um script SQL de cenários rodando contra o Supabase local. As de grupo vêm primeiro, para os cenários criarem grupos pelo caminho real, com quem cria entrando como admin.
5. **App.** Feed com selo de grupo, tela de jogo, confirmação e cancelamento, painel de débitos e painel de recebimentos.
6. **Comprovante.** Captura, compressão, reconhecimento de texto, upload para o espaço privado, função de envio, `apagar_comprovante` e URL assinada na leitura.
7. **Avisos.** Tabela, gatilho, Edge Function, FCM no aparelho, `registrar_dispositivo`, sino e marcação de lido.
8. **Rotinas.** A função de minuto e o agendamento em `pg_cron`.
9. **Convites.** `gerar_convite`, `revogar_convite` e `aplicar_convite`, tela de entrar com código, página do GitHub Pages e `app_links`.
10. **Distribuição.** Firebase App Distribution e um workflow diário no GitHub Actions para o projeto não pausar.

## Riscos e limites do plano gratuito

| Risco | Tratamento |
| --- | --- |
| O projeto no Supabase pausa após uma semana sem atividade | Um workflow do GitHub Actions faz uma requisição por dia; durante o piloto o uso real já basta |
| 500 MB de banco e 1 GB de arquivos | Comprimir a imagem do comprovante para algo em torno de 200 KB antes do upload; a retenção de um mês (RNF03) devolve espaço sozinha |
| 300 mensagens por dia no SMTP | Folgado para dezenas de pessoas: o pico é entrada, não aviso, e aviso vai por push |
| A FCM exige conta de serviço na API atual, não mais a chave antiga | A Edge Function assina o token da conta de serviço; o segredo fica na função, nunca no app |
| Instalar APK fora da loja tem ficado mais restrito no Android | Se barrar, o caminho é o teste interno da Play: US$ 25 uma única vez, o único gasto previsto do projeto |
| O reconhecimento de texto roda no cliente e poderia ser falsificado | A classificação é calculada no servidor e a baixa continua sendo decisão do credor (RN09), então o estrago máximo é uma dica errada na tela dele |
| Sem iOS no piloto | Registrado em Fora do MVP; nada no modelo nem nas regras depende da plataforma |
| Os limites acima mudam sem aviso | Conferir nas páginas de preço do Supabase e do provedor de e-mail antes de criar as contas; nenhum deles é premissa de regra, só de custo |
