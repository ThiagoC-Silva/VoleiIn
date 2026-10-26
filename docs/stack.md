# Stack — VoleiIn

Oct 16, 2026 · @Thiago

Como o MVP descrito no [PRD](prd.md) é construído. O PRD diz o que o produto faz e o [modelo de dados](modelo-de-dados.md) diz o que ele guarda; este documento diz onde cada coisa roda. A referência normativa continua sendo o PRD: quando houver divergência, ele vence.

A restrição que organiza tudo aqui é custo. O piloto cabe inteiro em planos gratuitos, sem nenhum custo variável por evento, e é isso que justifica cada escolha abaixo — inclusive as que trocam conforto por preço, como não ter iOS e não ter tela de administração.

## Escolhas

| Camada | Escolha | Custo |
| --- | --- | --- |
| App | Flutter, Android nativo, `minSdk` 24, layout de celular, `applicationId` `br.com.voleiin` | R$ 0 |
| Distribuição | Firebase App Distribution, convite por e-mail e build por link | R$ 0 |
| Banco e API | Postgres do Supabase, com política de linha; o app consulta direto, sem servidor no meio | R$ 0 até 500 MB |
| Autenticação | Supabase Auth, e-mail e senha (`signInWithPassword`), com código de seis dígitos por e-mail no cadastro, na redefinição de senha e na troca de e-mail; Google nativo pelo pacote `google_sign_in` e `signInWithIdToken` | R$ 0 até 50 mil contas ativas por mês |
| Login Google | Cliente OAuth no Google Cloud, tela de consentimento externa só com escopos básicos | R$ 0 |
| Envio de e-mail | Resend como SMTP próprio do Supabase Auth, 3.000 mensagens por mês com teto de 100 por dia | R$ 0 |
| Domínio do remetente | `voleiin.com.br`, registrado no Registro.br; os provedores de e-mail só autenticam domínio próprio | R$ 40 por ano |
| Push | Firebase Cloud Messaging, pelo pacote `firebase_messaging` | R$ 0, sem teto |
| Arquivos | Supabase Storage, espaço privado e URL assinada curta | R$ 0 até 1 GB |
| Leitura do comprovante | `google_mlkit_text_recognition`, reconhecimento no próprio aparelho | R$ 0, sem rede |
| Regras de negócio | Funções plpgsql no Postgres, chamadas por RPC | R$ 0 |
| Rotinas periódicas | `pg_cron` dentro do banco, uma varredura por minuto | R$ 0 |
| Disparo de push | `pg_net` chamando uma Edge Function que fala com a FCM | R$ 0 até 500 mil chamadas por mês |
| Página de convite | Arquivo estático no GitHub Pages | R$ 0 |
| Proximidade de locais | `geolocator` no app, distância calculada em SQL | R$ 0, sem API de mapa |
| Base de locais | Supabase Studio, direto nas tabelas (RN18) | R$ 0 |

Nenhuma linha tem custo por evento: o que cresce com o uso é espaço e tráfego, não conta. O gasto fixo é a anuidade do domínio, R$ 40. Fora dela, o único gasto previsto é de US$ 25, uma única vez, se a distribuição direta do APK for barrada e o caminho virar o teste interno da Play.

O provedor entra como SMTP próprio do Supabase Auth, porque o servidor embutido no plano gratuito entrega duas mensagens por hora e só para endereços da equipe do projeto: serve apenas para teste. Conferido em 26/10/2026, todo provedor sério exige um domínio próprio autenticado com SPF e DKIM, porque o Gmail e o Outlook passaram a recusar quem não tem — daí a anuidade do domínio na tabela. A escolha é o Resend, que verifica o domínio e libera o envio sem intervenção humana. O Brevo, considerado antes, entrega 300 mensagens por dia, mas exige aprovação manual de toda conta por pedido ao suporte, sem prazo publicado; fica como alternativa se o teto diário do Resend apertar.

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

A credencial — e-mail e senha, ou o vínculo com a conta Google — vive no Supabase Auth, em `auth.users` e `auth.identities`; `Pessoa` é só o perfil. Os dois se ligam pelo id: um gatilho cria a linha de `Pessoa` com o mesmo UUID do usuário quando o e-mail dele fica confirmado, e nenhuma chave estrangeira amarra as duas.

A ausência dessa chave é deliberada. A exclusão de conta precisa apagar o usuário — é o que faz a credencial deixar de existir — e **preservar** o perfil anonimizado, porque participações e cobranças de terceiros apontam para ele (RN27). Com chave estrangeira em cascata, apagar o usuário levaria o histórico; sem ela, o perfil sobrevive sozinho, anônimo e sem forma de login. O ganho secundário é que a política de linha compara `id = auth.uid()` direto, sem subconsulta.

O nome chega ao gatilho pelos metadados do usuário, porque `Pessoa.nome` é obrigatório (RN21). No cadastro com senha, o app manda o nome em `data: {'nome': ...}`; na entrada pelo Google, o serviço grava nos metadados o que o Google informa, e o nome vem em `full_name` ou `name`. O gatilho usa o primeiro preenchido nessa ordem — `nome`, `full_name`, `name` —, sem espaços nas pontas. São dois gatilhos em `auth.users`. Antes do `insert`, um confere esse nome e, se vier vazio, recusa o cadastro inteiro: o pedido falha na hora, e não só depois, no código. Uma conta Google sem nome também é recusada, em vez de nascer com um nome inventado. Quando `email_confirmed_at` passa de nulo para preenchido, o outro cria a `Pessoa` com esse nome, na mesma transação que confirma o código, e por isso a sessão devolvida ao app já encontra o perfil. Usuário inserido já confirmado — quem entra pelo Google pela primeira vez, ou quem é criado pelo Studio — ganha perfil no próprio `insert`. Assim não existe perfil sem nome, nem perfil de cadastro abandonado: um e-mail digitado errado deixa só um usuário não confirmado no serviço de autenticação, que não entra em nada e não aparece em lugar nenhum. A foto do Google fica só nos metadados do serviço; `avatar_url` nasce vazio.

O cadastro é `signUp(email, password, data: {'nome': ...})`, e o código que chega no modelo de confirmação é conferido com `verifyOTP(type: email)`. Se o e-mail já tem conta confirmada, o serviço não envia nada e responde de um de dois jeitos, conforme a configuração: o erro `user_already_exists`, como no local, ou um usuário sem `identities`, para não revelar a conta. O app trata os dois como e-mail que já tem conta, e a tela aponta a senha e o Google. O custo aceito é a tela revelar se um e-mail já tem conta. A entrada é `signInWithPassword`; em conta ainda não confirmada, o serviço responde `email_not_confirmed`, e a tela reenvia o código com `resend(type: signup)` e segue para a etapa do código. O Google é nativo: o pacote `google_sign_in` abre o seletor de contas do Android e devolve um ID token, que o app troca por sessão com `signInWithIdToken(provider: google)`, sem navegador, deep link nem URL de retorno. A redefinição de senha (RF41), esquecida ou a partir da sessão ativa, é `resetPasswordForEmail`, que manda o código no modelo de redefinição, seguido de `verifyOTP(type: recovery)`, `updateUser(password: ...)` e `signOut(scope: others)`. A senha nova é pedida junto com o código, antes de conferi-lo, porque a sessão nasce na conferência e a raiz do app troca de tela nesse momento. Para e-mail sem conta, o serviço responde igual e não envia nada.

Para o cadastro ficar pendente até o código, a confirmação de e-mail é ligada (`enable_confirmations = true`), no local e no remoto. Ela evita dois problemas. O primeiro é o e-mail digitado errado: desligada, o serviço confirma o usuário já no pedido, e o perfil nasceria antes de alguém provar que é dono do endereço. O segundo é a tomada de conta pela vinculação do Google. O serviço vincula sozinho uma identidade Google ao usuário que já exista com o mesmo e-mail, e é isso que faz a mesma pessoa cair na mesma conta pelos dois caminhos (RN21). Se o Bruno cadastra com senha o e-mail da Carla e a conta nasce confirmada, a Carla, ao entrar pelo Google, cai na conta do Bruno, com a senha dele valendo. Com a conta ainda não confirmada, o serviço trata a vinculação como prova de posse do endereço: apaga a senha e os metadados do cadastro pendente e fica com os do Google, e o gatilho de confirmação cria a `Pessoa` com o nome do Google.

O mesmo risco volta pelo cadastro refeito. Quando o cadastro pendente é pedido de novo, o serviço não troca a senha nem os metadados: responde como a um cadastro novo, manda outro código e, na confirmação, ficam a senha e o nome do **primeiro** pedido. Conferido na T07: o Bruno cadastra o e-mail da Carla e não confirma; a Carla cadastra o mesmo e-mail com a senha dela, recebe o código e confirma; a conta nasce como "Impostor", a senha do Bruno entra e a da Carla é recusada. Pela entrada com senha isso não acontece, porque com a senha da Carla o serviço responde `invalid_credentials` antes de `email_not_confirmed`. Por isso o app, ao confirmar o código de um cadastro vindo da tela de criar conta, grava em seguida, com a sessão que acabou de nascer, o nome e a senha digitados ali: a senha por `updateUser(password: ...)`, ignorando `same_password`, que é a resposta do caso comum sem pedido anterior, e o nome direto em `pessoa`, que é uma das escritas permitidas ao app. Quando a senha muda de fato, a troca segue o caminho de qualquer outra: o aviso de senha trocada chega ao e-mail, e uma sessão que o Bruno tenha aberto nesse intervalo perde a renovação.

O Google pede um projeto no Google Cloud, sem custo. A tela de consentimento é externa, só com os escopos básicos (`openid`, `email`, `profile`), que dispensam verificação do Google. Até o passo 10 ela fica em modo de teste, em que só entram pelo Google as contas listadas como usuárias de teste, até 100; quem não está na lista continua entrando com e-mail e senha. Publicá-la exige uma página inicial e uma Política de Privacidade, que entram no passo 10, antes de o APK chegar à turma. O cliente **web** é o `serverClientId` do app, que entra por `--dart-define`, e o `client_id` do provedor no Supabase, cujo segredo fica fora do repositório: no local, por `env()` no `config.toml`, lido de `supabase/.env`; no remoto, no painel. O cliente **Android** amarra o pacote `br.com.voleiin` ao SHA-1 da chave que assina o APK, e precisa de um SHA-1 por chave: a de debug de cada máquina de desenvolvimento e a do APK distribuído. Sem o SHA-1, o seletor de contas falha só naquele build. No local, o provedor roda com `skip_nonce_check = true`, que o Supabase CLI exige para o Google.

O Supabase Auth atende a RNF06 por configuração. A senha tem no mínimo oito caracteres (`minimum_password_length = 8`), sem regra de composição (`password_requirements` vazio); a checagem de senha vazada é recurso de plano pago e fica de fora. O código tem seis dígitos (`otp_length = 6`), validade de cinco minutos (`otp_expiry = 300`) e uso único. O limite por endereço é o intervalo mínimo de 60 segundos entre envios ao mesmo e-mail (`max_frequency`), que vale para confirmação, redefinição e troca, no máximo 60 por hora; o teto do projeto é de 30 por hora (`rate_limit.email_sent`), para um pico de cadastros não esgotar de uma vez as 100 mensagens diárias do Resend. As tentativas de entrada com senha são limitadas por IP (`rate_limit.sign_in_sign_ups`), e as de código também (`rate_limit.token_verifications`). Os modelos de e-mail são em português: confirmação do cadastro, redefinição de senha e troca de e-mail mostram o código (`{{ .Token }}`), não um link; o aviso de troca de e-mail, ao endereço antigo, e o de senha trocada (`notification.password_changed`) só informam. O produto não implementa hash, geração de código nem contagem de tentativas.

A entrada só por código (`signInWithOtp`) continua aberta no serviço, que não a desliga separada da senha, mas o app não a usa e ela não tem modelo próprio: quem a chamar pela API recebe o modelo padrão do serviço. Não é brecha, porque, como a redefinição de senha, só deixa entrar quem controla o e-mail.

A RNF07 é atendida pelo par de tokens do serviço. Na troca de e-mail, o código vai só ao endereço novo (`double_confirm_changes = false`) e o antigo recebe o aviso de troca concluída (`notification.email_changed`). Ligar a confirmação dupla não adiantaria: no fluxo por código, o serviço conclui a troca com qualquer um dos dois códigos sozinho. Confirmada a troca de e-mail ou de senha, o app chama `signOut(scope: others)`: as outras sessões caem e a do aparelho que confirmou continua. Na exclusão, o `signOut` é global.

Com `secure_password_change = true`, o serviço só aceita `updateUser(password)` de sessão criada nas últimas 24 horas; fora disso, exige um código de reautenticação, que o app não usa. O caminho do app sempre passa, porque a conferência do código de redefinição cria uma sessão nova. O que a opção fecha é uma sessão antiga, esquecida noutro aparelho, trocar a senha pela API sem código. Uma sessão de menos de 24 horas ainda consegue; nesse caso, o aviso de senha trocada chega ao e-mail, e a redefinição pelo código derruba essa sessão.

Os aparelhos de push não dependem do app cooperar: um gatilho na mudança de `email` ou de `encrypted_password` em `auth.users` apaga todo `dispositivo_push` do titular, e o aparelho que confirmou registra a si mesmo de novo. Como o `email` só muda depois da confirmação, o gatilho não dispara em troca apenas pedida. Ele também dispara quando o serviço apaga a senha de um cadastro pendente na vinculação do Google, mas aí ainda não há perfil, e portanto não há aparelho.

As funções de gatilho ficam no schema `privado`, na migração `autenticacao`, e não são RPC.

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
  lib/core/     cliente Supabase, cliente Google, tema, rotas, fuso; em widgets/,
                as peças do design system que as telas repetem
  lib/dados/    modelos e repositórios, um por agregado, chamando as funções
  lib/features/ auth, feed, jogo, grupo, cobranca, comprovante, perfil, avisos
  assets/fonts/ Montserrat e Bebas Neue (docs/design/DESIGN.md)
web-convite/    página estática do GitHub Pages
```

Pacotes do app, todos gratuitos: `supabase_flutter`, `google_sign_in`, `firebase_core`, `firebase_messaging`, `google_mlkit_text_recognition`, `image_picker`, `flutter_image_compress`, `geolocator`, `app_links`, `intl`, `flutter_riverpod`, `material_symbols_icons` e `shared_preferences`. Os dois últimos vêm do design system ([`docs/design/DESIGN.md`](design/DESIGN.md)): os ícones Material Symbols Rounded e a escolha do modo claro, guardada no aparelho.

O convite tem dois caminhos para a mesma coisa (RN22): um código curto que a pessoa cola na tela de entrar, e um link que a página do GitHub Pages redireciona para o app. O código existe porque é o que funciona quando o link não abre.

## Ordem de implementação

Cada passo fecha antes do seguinte começar.

1. **Schema.** Enums, tabelas, índices e unicidades. Atenção ao índice único de `id_transacao`, que precisa ser parcial: vários comprovantes ilegíveis entram sem identificador e não disputam entre si (RN10).
2. **Política de linha.** Uma política por tabela, mais a negação de escrita em Local, Quadra e HorarioFuncionamento, e a função `listar_participantes`.
3. **Autenticação.** Projeto no Supabase, Resend como SMTP, e-mail e senha com código de seis dígitos e cinco minutos no cadastro, na redefinição e na troca de e-mail, cliente OAuth do Google, gatilhos de criação do perfil e de revogação dos aparelhos, telas de entrar, de redefinir a senha e de trocar o e-mail.
4. **Núcleo financeiro.** As funções de grupo (`criar_grupo`, `editar_grupo`, `promover_admin`, `remover_membro`, `sair_grupo`), de jogo, presença e cobrança, com um script SQL de cenários rodando contra o Supabase local. As de grupo vêm primeiro, para os cenários criarem grupos pelo caminho real, com quem cria entrando como admin.
5. **App.** Feed com selo de grupo, tela de jogo, confirmação e cancelamento, painel de débitos e painel de recebimentos.
6. **Comprovante.** Captura, compressão, reconhecimento de texto, upload para o espaço privado, função de envio, `apagar_comprovante` e URL assinada na leitura.
7. **Avisos.** Tabela, gatilho, Edge Function, FCM no aparelho, `registrar_dispositivo`, sino e marcação de lido.
8. **Rotinas.** A função de minuto e o agendamento em `pg_cron`.
9. **Convites.** `gerar_convite`, `revogar_convite` e `aplicar_convite`, tela de entrar com código, página do GitHub Pages e `app_links`.
10. **Distribuição.** Página inicial e Política de Privacidade no GitHub Pages, publicação da tela de consentimento do Google, Firebase App Distribution e um workflow diário no GitHub Actions para o projeto não pausar.

## Riscos e limites do plano gratuito

| Risco | Tratamento |
| --- | --- |
| O projeto no Supabase pausa após uma semana sem atividade | Um workflow do GitHub Actions faz uma requisição por dia; durante o piloto o uso real já basta |
| 500 MB de banco e 1 GB de arquivos | Comprimir a imagem do comprovante para algo em torno de 200 KB antes do upload; a retenção de um mês (RNF03) devolve espaço sozinha |
| 100 mensagens por dia no SMTP | Folgado para dezenas de pessoas: entrar não envia e-mail, o pico é cadastro, e aviso vai por push |
| O domínio do remetente vence todo ano, e vencido derrubaria o login inteiro, não só o e-mail | Vencimento no calendário, com alerta; o registro atual vai até 26/10/2027 |
| O login pelo Google só funciona no build cuja chave de assinatura tem SHA-1 cadastrado no cliente Android | Cadastrar o SHA-1 da chave de debug de cada máquina; hoje o APK release assina com a chave de debug de quem o gerou, e a chave própria do APK distribuído, com seu SHA-1, entra no passo 10 |
| A tela de consentimento do Google em modo de teste só aceita os usuários listados | Até o passo 10, listar como usuárias de teste só as contas de desenvolvimento. No passo 10, publicá-la como externa, só com escopos básicos, que não pedem verificação do Google, com a página inicial e a Política de Privacidade no GitHub Pages |
| A FCM exige conta de serviço na API atual, não mais a chave antiga | A Edge Function assina o token da conta de serviço; o segredo fica na função, nunca no app |
| Instalar APK fora da loja tem ficado mais restrito no Android | Se barrar, o caminho é o teste interno da Play: US$ 25 uma única vez, o único gasto além da anuidade do domínio |
| O reconhecimento de texto roda no cliente e poderia ser falsificado | A classificação é calculada no servidor e a baixa continua sendo decisão do credor (RN09), então o estrago máximo é uma dica errada na tela dele |
| Sem iOS no piloto | Registrado em Fora do MVP; nada no modelo nem nas regras depende da plataforma |
| Os limites acima mudam sem aviso | Conferir nas páginas de preço do Supabase e do provedor de e-mail antes de criar as contas; nenhum deles é premissa de regra, só de custo. Conferido em 26/10/2026: os limites do Supabase continuam valendo, e o que mudou foi a exigência de domínio próprio, que tirou o envio de e-mail do R$ 0 |
