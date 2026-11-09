# Stacks do Projeto
 
## 1. Premissas
 
- **Prioridade:** arquitetura escalável desde o início.
- **Produto:** aplicativo mobile para Android. O iOS está fora do escopo inicial, por falta de equipamento para desenvolver e publicar. O uso do Flutter mantém a porta aberta para incluí-lo depois (ver pendências, seção 14).
- **Público:** grupo local de Parnaíba (PI), com pagamentos em Pix.
## 2. Resumo das decisões
 
| Camada | Escolha |
|--------|---------|
| Frontend / App | Flutter (alvo: Android) |
| Backend e banco de dados | Supabase (Postgres, Auth, Storage, Edge Functions, Realtime) |
| Região do Supabase | São Paulo (`sa-east-1`) |
| Notificações push | Firebase Cloud Messaging (FCM) |
| E-mails de autenticação | Resend, como SMTP próprio do Supabase Auth, enviando por `mail.voleiin.com.br` |
| Leitura de comprovantes | LLM com visão (Claude API), com validação determinística em código |
| Tarefas agendadas | `pg_cron` + Edge Functions |
| Deep links e convites | App Links (Android) próprios |
| Hospedagem da página de convite | Cloudflare Pages, em subdomínio do domínio próprio |
| Observabilidade | Logs nativos do Supabase (ferramenta dedicada adiada) |
| CI/CD e ambientes | GitHub Actions + Supabase CLI |
| Testes | Pirâmide completa (unitário, widget, banco, functions e integração) |
 
## 3. Frontend: Flutter
 
**Por quê:** um único código com boa performance e acesso aos recursos nativos exigidos pelos requisitos (push, câmera e galeria, compartilhamento, deep links). O alvo atual é só Android, e manter o Flutter permite adicionar o iOS depois sem reescrever o app.
 
### 3.1 Bibliotecas previstas
 
| Necessidade | Biblioteca sugerida | Requisitos |
|-------------|---------------------|------------|
| Integração com o backend | `supabase_flutter` | RF01 a RF07, RF105 a RF108 |
| Login com Google | `google_sign_in` (via Supabase Auth) | RF03, RF108 |
| Navegação e rotas | `go_router` | Todos |
| Deep links (convites de grupo e jogo) | `app_links` | RF15, RF16, RF43, RF48 |
| Foto de perfil e do grupo, comprovante | `image_picker`, `file_picker` (fotos redimensionadas para até 1024 px antes do envio, RN106) | RF09, RF14, RF78 |
| Compartilhar lista em texto | `share_plus` | RF43, RF100 |
| Copiar chave Pix | `Clipboard` (nativo do Flutter) | RF77 |
| Push no aparelho | `firebase_core`, `firebase_messaging`, `flutter_local_notifications` | RF88 |
| Gerenciamento de estado | `flutter_riverpod` | Todos |
| Modelos imutáveis e JSON | `freezed` + `json_serializable` | Todos |
| Textos da interface e formatação | `flutter_localizations` + `intl` (`flutter gen-l10n`) | Todos |
| Fuso `America/Fortaleza` | `timezone` | RN01 |
| Ícones | `material_symbols_icons` | Todos |

A lista completa, com o que fica de fora e por quê, está em `arquitetura-app.md` (seção 3).
 
### 3.2 Organização do código
 
Arquitetura em camadas, organizada por funcionalidade (*feature-first*), para facilitar o crescimento do time e do app. O app fica em `app/`; o detalhe está em `arquitetura-app.md`:
 
```
app/lib/
  core/            # tema, rotas, erros, utilitários, cliente Supabase
  features/
    auth/          # RF01 a RF13, RF101, RF105 a RF108
    groups/        # RF14 a RF25, RF102, RF103
    games/         # RF26 a RF45
    attendance/    # RF46 a RF55
    penalties/     # RF56 a RF65
    splits/        # RF66 a RF76
    payments/      # RF77 a RF87
    notifications/ # RF88 a RF100, RF104
  shared/          # widgets e componentes reutilizáveis
```
 
Cada feature segue: `data` (repositórios e acesso ao Supabase), `domain` (modelos e regras) e `presentation` (telas, widgets e providers).
 
## 4. Backend: Supabase
 
**Por quê:** cobre autenticação, banco relacional, armazenamento privado e funções serverless em uma única plataforma gerenciada, sobre Postgres, que é uma base sólida para crescer.
 
### 4.1 Serviços utilizados
 
| Serviço | Uso no projeto | Requisitos |
|---------|----------------|------------|
| **Auth** | E-mail e senha com confirmação por link, Google com vinculação por e-mail verificado, recuperação e troca de senha, troca de e-mail, sessão persistente. Os e-mails saem pelo Resend, configurado como SMTP próprio | RF01 a RF07, RF106 a RF108 |
| **Postgres** | Dados de usuários, grupos, jogos, listas, multas, rateio e pagamentos | Todos |
| **Row Level Security (RLS)** | Controle de acesso por membro, admin do jogo, recebedor e visibilidade do perfil e do telefone | RF17, RF34, RF74, RF87, RF101 |
| **Storage (buckets privados)** | Fotos de perfil e de grupo, e comprovantes com acesso restrito ao pagador e ao recebedor | RF09, RF14, RF78, RF87 |
| **Edge Functions** | Validação de comprovante, envio de push, prévia de convite e limpeza de arquivos (`contratos-api.md`). A conclusão de jogo e o rateio são funções SQL | RF16, RF48, RF78 a RF83, RF87, RF88 a RF97, RF104 |
| **Realtime** | Atualização ao vivo da lista de presença, do status do jogo e do sino de notificações | RF38, RF46 a RF55, RF99 |
 
### 4.2 Decisões de arquitetura
 
- **Região:** todos os projetos ficam em São Paulo (`sa-east-1`), o que reduz a latência para usuários no Brasil e mantém o banco e o Storage no país. A região não pode ser trocada depois sem migrar o projeto, então a escolha vale desde o início.
- **Regras críticas no servidor:** rateio, multas, mudança automática de status (Aberto e Confirmado) e conclusão automática ficam em funções do banco ou Edge Functions, nunca apenas no app.
- **Concorrência nas vagas (RF51, RF52):** a disputa pela mesma vaga liberada é resolvida no banco, com transação e bloqueio de linha, para garantir que só o primeiro a confirmar fique com ela.
- **Dinheiro em centavos:** valores armazenados como inteiros, com arredondamento para cima na parte por vaga (RF67).
- **Anonimização em vez de exclusão (RF13):** o histórico de jogos e valores é mantido e os dados pessoais são anonimizados (detalhes em 13.2). Grupos excluídos são arquivados pelo mesmo motivo (RF103).
- **Idempotência dos comprovantes (RF81):** índice único parcial no ID da transação, aplicado aos comprovantes Aprovado ou Em análise (RN89). Quando o comprovante é recusado, o ID volta a ficar livre.
- **Modelo de dados:** tabelas, enums, constraints e índices estão no `modelo-dados.md`.
- **Migrações versionadas:** todo o schema é gerenciado com o Supabase CLI, no repositório.
- **Ambientes:** o Supabase local para desenvolvimento e homologação, e um projeto remoto só, a produção (seção 10.1, ADR 0011).
## 5. Notificações push: Firebase Cloud Messaging (FCM)
 
**Por quê:** é o padrão no Flutter, cobre o Android e não tem custo por mensagem. Se o iOS for incluído depois, o FCM também o atende, via APNs.
 
| Peça | Detalhe | Requisitos |
|------|---------|------------|
| App | `firebase_messaging` para registrar o aparelho e receber pushes; `flutter_local_notifications` para exibir com o app aberto | RF88 |
| Tokens de dispositivo | Tabela `device_tokens` (usuário, token, plataforma, última atualização), com remoção no logout e quando o FCM invalidar o token. O campo de plataforma é mantido para facilitar a inclusão do iOS depois | RF07, RF88 |
| Envio | Edge Function `send-push`, que chama a API HTTP v1 do FCM e atende a todos os eventos | RF89 a RF97, RF104 |
| Preferências | Tabela `notification_preferences` (usuário e tipo), consultada antes de cada envio | RF98 |
| Histórico (sino) | Tabela `notifications`, gravada a cada envio e lida pelo app com Realtime | RF99 |
 
**Regras de envio:**
- Todo evento grava primeiro em `notifications` e só então dispara o push, respeitando as preferências do usuário.
- A cobrança das 9h e 20h (RF96) é **uma notificação por usuário**, com o total Pendente, no fuso `America/Fortaleza` (RN01). Valores Em análise não entram no total (RN113).
## 6. Comprovantes: LLM com visão (Claude API)
 
**Por quê:** os comprovantes Pix variam por banco e podem vir como imagem ou PDF. Um modelo com visão extrai os campos em JSON sem precisar de regras específicas por instituição.
 
### 6.1 Fluxo
 
1. O app envia o arquivo para um bucket privado do Storage (RF78, RF87) e desabilita novo envio para o mesmo valor até receber o resultado (RN86).
2. A Edge Function `process-receipt` é acionada com o caminho do arquivo.
3. A função verifica o limite de **3 leituras automáticas por valor a pagar** (RN86). Dentro do limite, gera uma URL assinada de curta duração, envia o arquivo à Claude API e pede **JSON estruturado**: valor, data e hora, destinatário e ID da transação (RF79). A partir da 4ª tentativa, o envio vai direto para **Em análise**, sem chamar a API. Envios recusados por ID repetido contam como leitura. Uma falha da API não conta (RN86).
4. A função aplica as regras **em código, não no modelo**:
   - valor exato igual ao valor a pagar;
   - destinatário compatível com o **recebedor gravado no próprio valor a pagar** (RN32), comparando com a chave Pix atual dele ou com o nome;
   - data e hora iguais ou posteriores ao **início do jogo**, **comparadas no minuto**, lendo a hora do comprovante em `America/Sao_Paulo` (RN88c). Pagamentos feitos depois da partida e antes da conclusão são aprovados normalmente;
   - ID da transação não utilizado em comprovante **Aprovado ou Em análise** de outro valor a pagar (RN89). Se aquele comprovante for recusado, o ID volta a ficar livre.
5. Antes de gravar o resultado, a função bloqueia a linha do valor a pagar e confere que ele continua **Pendente**. Isso protege contra dois envios simultâneos, já que o bloqueio de novo envio é feito só no app.
6. Resultado:
   - tudo conferido: o valor a pagar vai para **Pago** (RF82) e o recebedor é notificado (RF104);
   - leitura falhou ou houve divergência: **Em análise**, com notificação ao recebedor (RF83);
   - ID de transação repetido: envio recusado, com o motivo informado ao pagador (RF81, RN89).
### 6.2 Cuidados
 
- A chave da API fica apenas nos *secrets* das Edge Functions, nunca no app.
- O modelo apenas **extrai** dados. A decisão de aprovar é sempre da regra determinística.
- Índice único parcial no ID da transação (comprovantes Aprovado ou Em análise, RN89), para impedir reaproveitamento mesmo em envios simultâneos.
- Limite de tamanho (10 MB) e de tipos aceitos (imagem e PDF), validado no app e no servidor (RN87).
- Modelo e versão configuráveis por variável de ambiente, para trocar sem novo deploy do app.
## 7. Tarefas agendadas: `pg_cron` + Edge Functions
 
**Por quê:** mantém tudo dentro do Supabase, sem infraestrutura extra. O `pg_cron` dispara no horário e chama funções SQL ou Edge Functions (via `pg_net`).
 
| Tarefa | Frequência | Requisitos |
|--------|------------|------------|
| Concluir automaticamente os jogos 1 hora após o fim, sem registrar novas faltas, mantendo as já registradas pela saída após o início, e com o valor total informado (RN49) | A cada 5 minutos | RF42 |
| Lembrete 2 horas antes do prazo de cancelamento | A cada 5 minutos | RF92 |
| Lembrete 2 horas antes do início do jogo | A cada 5 minutos | RF93 |
| Aviso aos admins no horário de fim, para concluir o jogo | A cada 5 minutos | RF94 |
| Cobrança dos valores pendentes às 9h e às 20h, uma notificação por usuário | Diária (2 execuções) | RF96 |
| Exclusão dos arquivos de comprovantes decididos há mais de 30 dias | Diária | RF87 (ver 13.1) |
 
**Boas práticas:**
- Cada lembrete é registrado em uma tabela de controle (`scheduled_notifications_log`), com restrição de unicidade por tipo, usuário, jogo e **horário de referência** (RN111). Isso torna a tarefa **idempotente** (se rodar duas vezes, não envia duas vezes) e faz um jogo remarcado gerar um lembrete novo.
- Os horários são calculados em UTC no banco e convertidos para `America/Fortaleza` apenas na exibição e nos horários fixos (RN01).
- A conclusão automática e a manual usam a **mesma função** de rateio, para garantir regras idênticas.
- Se o volume crescer, as tarefas podem passar a enfileirar o trabalho (com `pgmq`, por exemplo) sem mudar o restante da arquitetura.
## 8. Deep links e convites
 
**Por quê:** App Links próprios funcionam sem custo e sem dependência de terceiros. Um link `https://` abre o app direto quando instalado e, se não estiver, leva a uma página web com o botão da Google Play.
 
| Peça | Detalhe | Requisitos |
|------|---------|------------|
| Endereços | `https://convite.voleiin.com.br/g/<codigo>` (grupo) e `https://convite.voleiin.com.br/j/<codigo>` (jogo) | RF15, RF43 |
| Android | Arquivo `/.well-known/assetlinks.json` e *intent filters* com `autoVerify` | RF16, RF48 |
| App | `app_links` captura o link e o `go_router` abre a tela de entrada no grupo ou no jogo | RF16, RF48 |
| Página de fallback | Página estática com o botão da Google Play e o código de convite visível. Se for aberta em um aparelho que não seja Android (iPhone ou computador), exibe um aviso de que o app está disponível apenas para Android por enquanto | RF15, RF43 |
 
**Regras:**
- O código de convite é gerado e validado no servidor. Cada código aponta para um grupo ou jogo e pode ser invalidado ou regenerado pelo admin. O código de um grupo excluído é invalidado (RF103).
- Entrar por link de **grupo** cria uma solicitação pendente (RF16). Entrar por link de **jogo** coloca o usuário na lista, se houver vaga (RF48).
- Se o usuário não estiver logado, o app guarda o convite, conduz o login e retoma o fluxo depois.
- **Deferred deep link** (preservar o convite durante a instalação pela loja) não vem pronto nessa abordagem. Como alternativa, a página de fallback exibe o código para ser digitado no app, entrada que o RF16 já prevê. Como o alvo é só Android, o *Play Install Referrer* pode viabilizar o deferred deep link no futuro, se for necessário.
### 8.1 Hospedagem: Cloudflare Pages
 
**Por quê:** o plano gratuito tem largura de banda e requisições estáticas ilimitadas e aceita domínio próprio com HTTPS. Uma página estática com um arquivo de verificação fica muito abaixo dos limites (500 builds por mês e 1 build simultâneo). Foram descartados o Vercel, cujo plano gratuito é restrito a uso não comercial, e o Firebase Hosting, limitado a 360 MB de transferência por dia no plano gratuito.
 
| Item | Configuração |
|------|--------------|
| Domínio | Subdomínio do domínio próprio (`convite.voleiin.com.br`), apontado por CNAME para o projeto no Cloudflare Pages. Usar o domínio raiz exigiria mover o DNS inteiro para a Cloudflare |
| Conteúdo | Página estática de fallback e `/.well-known/assetlinks.json` |
| Rotas de convite | `/g/<codigo>` e `/j/<codigo>` servem a mesma página, que lê o código e mostra o botão da loja |
| Deploy | Repositório no GitHub conectado ao Cloudflare Pages, com publicação automática a cada *merge* na branch principal |
 
**Cuidados:**
- O arquivo de verificação deve ser servido por HTTPS, **sem redirecionamento**, ou o Android não valida o domínio.
- O domínio de cada App Link (nos *intent filters*) deve ser exatamente o subdomínio escolhido, em todos os ambientes.
- Uso comercial no plano gratuito: conferir os termos da Cloudflare antes do lançamento, já que o app envolve cobranças entre usuários.
## 9. Observabilidade (fase inicial)
 
Decisão de adiar uma ferramenta dedicada de monitoramento. Nesta fase:
 
- **Logs e métricas** pelo painel do Supabase (Auth, Postgres, Storage e Edge Functions).
- **Advisors do Supabase** para checar segurança (RLS) e performance (índices) a cada mudança de schema.
- **Logs estruturados nas Edge Functions** (JSON com evento, identificadores e resultado), em especial nas de comprovantes, push e tarefas agendadas. Isso facilita adotar uma ferramenta depois, sem refatorar.
**Gatilho para revisitar:** os primeiros usuários reais em produção, ou qualquer incidente que o log nativo não ajude a investigar. A candidata natural é o Sentry, que cobre o app Flutter e as Edge Functions.
 
## 10. CI/CD e ambientes
 
### 10.1 Ambientes
 
| Ambiente | Supabase | App |
|----------|----------|-----|
| **Local** (desenvolvimento e homologação) | Supabase local (`supabase start`) | Build de debug no emulador |
| **Produção** | Projeto `VoleiIn` (o do v0, limpo na fatia 1) | Google Play |
 
Não há projeto remoto de homologação (ADR 0011). O app é um só, `br.com.voleiin`, sem *flavors*, e o ambiente é escolhido por `--dart-define-from-file`, sem chaves fixas no código (ADR 0012). Detalhes em `setup.md`.
 
### 10.2 Pipelines (GitHub Actions)
 
| Gatilho | O que roda |
|---------|------------|
| *Pull request* | `dart analyze`, `flutter test`, formatação, validação das migrações (`supabase db lint` e aplicação em banco limpo), `supabase test db` e `deno test` |
| *Merge* na branch principal | Nada no Supabase. Publicação da página de convite no Cloudflare Pages |
| Deploy (disparo manual) | Migrações e functions em **produção**, mais build assinado do app (Android App Bundle). O disparo é a aprovação manual e exige o ensaio da migração (`setup.md`, seção 9.2) |
 
### 10.3 Regras de trabalho
 
- Todo o schema vive em migrações versionadas no repositório. Nenhuma alteração manual de banco em produção.
- Segredos (chave da Claude API, credenciais do FCM, tokens do Supabase e *keystore* de assinatura do app) ficam nos *secrets* do GitHub e do Supabase.
- Testes de RLS e das funções críticas rodam no banco local durante o CI.
## 11. Estratégia de testes
 
| Nível | Ferramenta | O que cobre | Quando roda |
|-------|-----------|-------------|-------------|
| **Unitário** | `flutter_test`, `mocktail` | Regras e modelos no app (formatação de valores, estados de tela, providers) | A cada PR |
| **Widget** | `flutter_test` | Telas e componentes (lista de presença, rateio, envio de comprovante) | A cada PR |
| **Banco** | pgTAP (`supabase test db`) | RLS, rateio, multas e mudança de status | A cada PR, em banco local |
| **Concorrência** | Deno test, com conexões separadas | Disputa de vagas, conclusão simultânea e comprovantes repetidos (`testes-referencia.md`, seção 8) | A cada PR, em banco local |
| **Edge Functions** | Deno test | `process-receipt`, `send-push`, `preview-invite` e `storage-cleanup`, com a Claude API e o FCM simulados | A cada PR |
| **Integração** | `integration_test` | Fluxos completos: cadastro, criar jogo, entrar na lista, concluir e pagar | No emulador, contra o Supabase local, antes do release |
 
**Prioridade de cobertura (maior risco primeiro):**
1. Rateio e arredondamento para cima ao centavo (RF67).
2. Multas e isenções, inclusive a ordem de isenção por cancelamento (RF56 a RF64).
3. Concorrência na ocupação de vagas liberadas (RF51, RF52) e transições entre Aberto e Confirmado (RF38).
4. Políticas de RLS: quem vê perfis, grupos, jogos, rateio, comprovantes e telefone (RF74, RF87, RF101).
5. Validação de comprovantes: valor exato, destinatário, data no minuto a partir do início do jogo, ID de transação repetido e envios simultâneos (RF80, RF81).
**Regras:**
- Os testes de comprovantes usam um conjunto fixo de exemplos (imagens e PDFs de vários bancos, inclusive ilegíveis), com a resposta esperada para cada um. O teste de integração com a API real roda à parte e não bloqueia o PR.
- Todo bug corrigido ganha um teste que o reproduz.
## 12. Dados sensíveis e visibilidade
 
Resumo de quem vê o quê, implementado por RLS no banco, não apenas na interface. "Compartilhar contexto" é ter em comum um grupo atual ou qualquer jogo, atual ou passado, na lista de presença ou de espera (RN107).
 
| Dado | Quem vê | Requisitos |
|------|---------|------------|
| Nome, apelido e foto | O próprio usuário e quem compartilha contexto com ele. Exceção: quem tem o convite de um jogo e está logado vê o apelido ou nome e a foto dos participantes na prévia (RN107) | RF19, RF46, RF48 |
| Chave Pix | O próprio usuário. Quando ele é o recebedor de um jogo não cancelado: os participantes da lista, desde a criação do jogo, e quem tem valor Pendente ou Em análise devido a ele (RN102) | RF11, RF45, RF77 |
| Telefone | O próprio usuário. Se ele marcar como visível, também quem compartilha contexto com ele. O padrão é oculto | RF10, RF101 |
| Comprovante (arquivo e dados lidos) | O pagador e o recebedor | RF87 |
| Rateio completo | O recebedor e os admins do jogo. Cada participante vê apenas o próprio valor | RF73, RF74 |
| E-mail | Apenas o próprio usuário | RF01 |
 
## 13. Segurança e conformidade (LGPD)
 
> Esta seção descreve decisões técnicas. Prazos, bases legais e textos devem ser validados com assessoria jurídica antes do lançamento.
 
### 13.1 Retenção de comprovantes (RF87)
 
- Os comprovantes ficam em bucket privado, acessíveis apenas ao pagador e ao recebedor, por URLs assinadas de curta duração.
- **Prazo de retenção do arquivo: 30 dias após a decisão sobre o comprovante** (aprovação automática, aprovação ou recusa pelo recebedor, ou recusa por ID repetido). Um *job* diário (seção 7) apaga o arquivo do Storage.
- **O registro do comprovante fica guardado por completo e sem prazo** no banco: dados extraídos (valor, data e hora, nome e chave do destinatário, ID da transação), resposta da leitura automática, resultado das conferências, status, decisão e observação do recebedor (RN91).
- O comprovante **Em análise** não tem o arquivo apagado: o prazo só começa a contar depois da decisão do recebedor (RN92).
- Após a exclusão do arquivo, o participante continua vendo o status e a observação do recebedor, mas não consegue abrir o arquivo (RF86).
- O ID da transação continua guardado, para que a regra de comprovante repetido (RF81) siga valendo.
### 13.2 Anonimização na exclusão da conta (RF13)
 
- A exclusão só é permitida sem valores a pagar ou a receber Pendentes ou Em análise, e se o usuário não for o último admin de um grupo nem o único admin ou o recebedor de um jogo Aberto ou Confirmado (RF13, RN103).
- **Anonimizados:** nome, apelido, foto, telefone, chave Pix e e-mail, tanto em `auth.users` quanto no perfil. Os arquivos de foto são apagados do Storage.
- **Mantidos:** histórico de jogos, presenças, multas, valores e comprovantes, associados a um perfil anônimo (por exemplo, "Usuário removido").
- Os tokens de push e as preferências de notificação são apagados.
- A operação roda em uma função do servidor, em transação única, e é registrada em log de auditoria sem dados pessoais.
### 13.3 Privacidade e consentimento
 
- Termos de Uso e Política de Privacidade aceitos no cadastro, com data, hora e versão do aceite registradas, e novo aceite quando a versão mudar (RF105).
- A política deve informar quais dados são tratados (inclusive telefone, chave Pix e comprovantes) e a finalidade de cada um.
- **Comprovantes e IA:** a política deve informar que o comprovante é enviado a um provedor de IA (Claude API) apenas para extrair os dados do pagamento, e que os dados extraídos ficam guardados no histórico do pagamento mesmo após a exclusão do arquivo. Antes do lançamento, conferir os termos de retenção e de uso de dados do provedor.
- Telefone e chave Pix são opcionais (RF10, RF11), com a visibilidade descrita na seção 12. A chave Pix não pode ser removida enquanto houver valores a receber (RN105).
- O usuário deve poder consultar e corrigir seus dados (RF12) e excluí-los (RF13).
### 13.4 Proteção contra abuso
 
| Risco | Medida |
|-------|--------|
| Acesso indevido a dados | RLS ativado em todas as tabelas, com testes automatizados (seção 11) |
| Uploads maliciosos ou muito grandes | Validação de tipo e de tamanho no app e no servidor, em bucket privado: fotos em JPEG, PNG ou WebP até 2 MB, redimensionadas no app (RN106); comprovantes em imagem ou PDF até 10 MB (RN87) |
| Abuso da Claude API (custo) | Até 3 leituras automáticas por valor a pagar (RN86), aceitando apenas arquivos vinculados a um valor Pendente |
| Força bruta e spam de cadastro | Rate limit do Supabase Auth, confirmação de e-mail (RF02) e, se necessário, CAPTCHA |
| Adivinhação de convites | Códigos longos e aleatórios, com opção de invalidar e regenerar (RF15) |
| Vazamento de chaves | Segredos apenas em *secrets* (Edge Functions e GitHub). No app, somente a chave pública (*anon*) do Supabase |
| Uso indevido de Edge Functions | Verificação do JWT do usuário em cada função, com as funções internas protegidas por chave de serviço |
 
## 14. Pendências
 
| Item | Responsável | Quando |
|------|-------------|--------|
| Revisão jurídica dos termos, da política de privacidade e dos prazos de LGPD, incluindo a guarda sem prazo dos dados extraídos dos comprovantes | Assessoria jurídica | Antes do lançamento |
| Confirmar que o plano gratuito do Cloudflare Pages permite uso comercial | Produto | Antes do lançamento |
| Conferir os termos de retenção e uso de dados da Claude API | Produto | Antes do lançamento |
| Escolher a ferramenta de observabilidade (candidata: Sentry) | Técnico | Após os primeiros usuários |
