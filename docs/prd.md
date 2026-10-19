Oct 16, 2026 · @Thiago

## Visão geral

O produto substitui a organização manual de jogos de vôlei que hoje acontece em grupos de WhatsApp: marcar horário e quadra, controlar quem confirmou, dividir o valor da locação e cobrar quem desistiu em cima da hora.

O MVP é um aplicativo Android, feito em Flutter, com layout de celular. O pagamento ocorre fora da plataforma, por Pix direto a quem pagou a quadra; o sistema registra quem deve, quanto e se já pagou.

### Escopo do MVP

Está dentro: conta por e-mail, grupos com regras próprias, jogos dentro de grupo ou avulsos, confirmação de presença com lista de espera, geração de cobranças, envio e leitura de comprovante, escolha do local em uma lista cadastrada, gestão de membros do grupo, duplicação de jogo anterior, avisos no app e por push, troca de e-mail e exclusão de conta.

Está fora: processamento de pagamento pela plataforma, agenda e reserva de quadra pelo app, cadastro e reivindicação de locais pelos usuários, jogo recorrente automático, reputação de jogadores, chat interno, painel administrativo de locais e aplicativo iOS.

### Glossário

| Termo               | Significado                                                           |
| ------------------- | --------------------------------------------------------------------- |
| Jogo                | Um encontro marcado, com data, local, número de vagas e custo total   |
| Grupo               | Turma recorrente que guarda padrões reaproveitados a cada jogo        |
| Jogo avulso         | Jogo sem grupo, criado para uma ocasião única                         |
| Criador             | Quem cria o jogo; por padrão é quem paga a quadra e recebe os rateios |
| Recebedor           | Quem pagou a quadra e recebe os rateios daquele jogo; definido pelo criador |
| Participação        | Vínculo entre uma pessoa e um jogo, com seu estado de presença        |
| Cobrança            | Valor que um participante deve ao credor por aquele jogo              |
| Credor              | Quem recebe o valor de uma cobrança; é o recebedor daquele jogo       |
| Devedor             | Quem deve o valor de uma cobrança; é o participante                   |
| Cancelamento tardio | Cancelamento feito depois de vencido o prazo de isenção, que mantém a cobrança devida (RN03) |

## Requisitos funcionais

Trinta e nove requisitos cobrem o MVP. A coluna de regras aponta para as RNxx da seção seguinte. A numeração salta a RF39, retirada quando a manutenção dos locais deixou de ser requisito do produto e virou operação do desenvolvedor (RN18).

| ID   | Descrição                                                                                                            | Regras           |
| ---- | -------------------------------------------------------------------------------------------------------------------- | ---------------- |
| RF01 | Criar conta e autenticar por e-mail, com código de seis dígitos                                                      | RN21             |
| RF02 | Editar o próprio perfil: nome, foto, telefone e chave Pix                                                            | RN24             |
| RF03 | Criar grupo definindo nome, cor e padrões de jogo (local, vagas, custo e prazo de cancelamento) | RN12             |
| RF04 | Entrar em um grupo por link de convite                                                                               | RN13, RN22       |
| RF05 | Listar membros do grupo e seus papéis                                                                                | RN13             |
| RF06 | Editar as regras do grupo                                                                                            | RN11, RN13       |
| RF07 | Criar jogo dentro de um grupo, herdando os padrões do grupo                                                          | RN01, RN12, RN14, RN15, RN24 |
| RF08 | Criar jogo avulso, informando todas as regras no próprio jogo                                                        | RN01, RN12, RN14, RN15, RN24 |
| RF09 | Convidar pessoas para um jogo por link                                                                               | RN22             |
| RF10 | Editar dados do jogo após a criação                                                                                  | RN13, RN20       |
| RF11 | Cancelar um jogo                                                                                                     | RN13, RN23       |
| RF12 | Exibir o feed pessoal com os jogos do usuário e os jogos abertos de seus grupos                                      | —                |
| RF13 | Filtrar o feed por grupo ou por jogos avulsos                                                                        | —                |
| RF14 | Confirmar presença em um jogo                                                                                        | RN01, RN06, RN25 |
| RF15 | Cancelar presença, com aviso prévio quando houver multa                                                              | RN02, RN03       |
| RF16 | Entrar automaticamente na lista de espera quando não houver vaga                                                     | RN08             |
| RF17 | Promover a lista de espera quando uma vaga for liberada                                                              | RN05, RN08       |
| RF18 | Marcar participantes que faltaram, após o jogo                                                                       | RN04, RN13, RN17 |
| RF19 | Gerar a cobrança na confirmação, bloqueada para pagamento até o encerramento                                                           | RN01, RN07       |
| RF20 | Exibir ao usuário seus débitos em aberto, com origem e credor                                                        | RN07             |
| RF21 | Exibir ao credor o painel de valores a receber, agrupados por devedor                                                | RN07             |
| RF22 | Confirmar manualmente o recebimento de uma cobrança                                                                  | RN13             |
| RF23 | Isentar uma cobrança                                                                                                 | RN05, RN13       |
| RF24 | Enviar comprovante de pagamento vinculado a uma cobrança                                                             | RN19             |
| RF25 | Ler o comprovante no aparelho e classificar sua consistência no servidor                                             | RN09             |
| RF26 | Impedir o reaproveitamento de um comprovante já usado                                                                | RN10             |
| RF27 | Escolher o local do jogo em uma lista cadastrada pelo desenvolvedor                                                                      | RN18             |
| RF28 | Buscar locais por nome ou proximidade                                                                                | —                |
| RF29 | Sair de um grupo                                                                                                     | RN30             |
| RF30 | Remover um membro do grupo                                                                                           | RN13, RN30       |
| RF31 | Promover um membro a admin do grupo                                                                                  | RN13             |
| RF32 | Revogar um convite de grupo                                                                                          | RN13, RN22       |
| RF33 | Encerrar o jogo manualmente                                                                                          | RN13, RN17       |
| RF34 | Duplicar um jogo anterior, informando apenas a nova data                                                             | RN28             |
| RF35 | Trocar o e-mail da conta                                                                                             | RN21             |
| RF36 | Excluir a própria conta                                                                                              | RN27             |
| RF37 | Apagar o próprio comprovante depois da baixa                                                                         | RN19             |
| RF38 | Receber avisos do sistema no app e, com autorização, por push                                                        | RN29             |
| RF40 | Listar os próprios avisos e marcá-los como lidos                                                                     | RN29             |

## Regras de negócio

As trinta regras abaixo estão fechadas. Elas são a referência normativa do MVP: a coluna de regras dos requisitos funcionais aponta para os IDs daqui, e o modelo de dados da seção seguinte já reflete o que ficou decidido.

### Dinheiro e rateio

| ID | Regra |
| --- | --- |
| RN01 | O valor por vaga é o custo total dividido pelo número de vagas, arredondado conforme a RN16. Alterar `custo_total` ou `vagas_total` recalcula esse valor e atualiza o valor de todas as cobranças ativas do jogo, inclusive as de origem `cancelamento_tardio` e `falta`; quem já confirmou é notificado. Um reajuste nunca gera segunda cobrança: a unicidade de uma cobrança por participação vale sem exceção (RN25), e o caso de reajuste sobre cobrança já paga não existe, porque o pagamento só é liberado no encerramento (RN07) e esses campos não são editáveis depois dele (RN20). Sem nenhum confirmado, a alteração é livre e não gera aviso |
| RN16 | O valor por vaga é arredondado para cima no centavo. A soma das vagas pode superar o custo total em até um centavo por vaga, e essa sobra fica com o recebedor. Em R$ 100,00 divididos entre sete vagas, cada uma paga R$ 14,29 e o recebedor fecha com R$ 100,03 |
| RN24 | Todo jogo guarda em `chave_pix_recebedor` a chave Pix do seu recebedor, copiada no momento em que o recebedor é definido. Por padrão o recebedor é o criador, e a criação exige que ele tenha `chave_pix` no perfil, pedindo-a no próprio formulário quando faltar. O criador pode trocar o recebedor de duas formas: escolhendo na lista de pessoas que já têm chave cadastrada, ou informando à mão a chave do novo recebedor — essa chave digitada vale apenas para aquele jogo e não altera o perfil de ninguém. A troca repete a exigência e migra o `credor_id` das cobranças (RN20). Para quem apenas joga, a chave segue opcional |
| RN07 | A cobrança nasce na confirmação da presença, com status `pendente`, e permanece congelada até o jogo ser encerrado (RN17): antes do encerramento o devedor não envia comprovante e o credor não dá baixa nem isenta à mão. O congelamento vale para atos das pessoas, não para as transições automáticas do sistema, que seguem valendo nesse intervalo — a isenção do cancelante tardio substituído (RN05) e o cancelamento das cobranças quando o jogo é cancelado (RN23). A cobrança vence 24 horas após o encerramento. O devedor recebe dois avisos (RN29): um no encerramento, quando o pagamento é liberado, e outro no vencimento. Depois disso, apenas o indicador de débito no app. A baixa e a isenção manual registram autor e momento em `confirmado_por` e `confirmado_em`: o par significa quem resolveu a cobrança e quando, não apenas quem confirmou pagamento, e é preenchido inteiro ou fica inteiro vazio. As transições automáticas não têm autor e deixam o par vazio — a isenção do substituído (RN05) e o cancelamento das cobranças do jogo cancelado (RN23) |

### Cancelamento, falta e vagas vazias

| ID | Regra |
| --- | --- |
| RN02 | O prazo sem multa é o início do jogo menos `prazo_cancelamento_horas`, comparado à hora do servidor em horário de Brasília, nunca à hora do aparelho. No jogo de grupo o valor vem do grupo e pode ser sobrescrito no jogo (RN12); no jogo avulso é obrigatório informá-lo. Jogo criado quando esse prazo já nasceu vencido mantém a multa valendo desde a criação, e a tela de confirmação avisa que cancelar já gera cobrança |
| RN03 | Cancelar depois do prazo mantém a cobrança devida pelo valor integral da vaga. Não há percentual configurável — `multa_percentual` deixa de existir no modelo — nem exceção automática por motivo justificado: o credor isenta a cobrança quando entender que é o caso (RF23) |
| RN04 | A falta é marcada pelo recebedor do jogo ou por um admin do grupo, até 24 horas após o encerramento; no jogo avulso, onde não há grupo, somente o recebedor marca. A marcação move a Participacao de `confirmado` para `faltou` e a Cobranca de origem `parte` para `falta`. O valor não muda: a origem é apenas o registro do desfecho, que serve a uma futura reputação de jogadores. O participante não contesta a falta pelo app |
| RN05 | Quando alguém da lista de espera confirma a vaga liberada, a cobrança do cancelante tardio é isenta. A isenção não é desfeita pelo que terceiros fizerem depois: se o substituto cancelar, ele responde pela própria multa e a isenção anterior continua valendo. O único caminho de volta é o próprio isento reconfirmar presença no jogo (RN25) — aí ele vai jogar, e paga a parte dele como qualquer outro |
| RN06 | Vaga que fica vazia é prejuízo do recebedor. Até o início do jogo, o criador pode reduzir `vagas_total` até o número de confirmados, o que recalcula o valor por vaga pela RN01 |
| RN25 | Quem cancelou fora do prazo pode confirmar presença de novo no mesmo jogo enquanto houver vaga aberta. A mesma Participacao volta a `confirmado` e a mesma Cobranca troca a origem de `cancelamento_tardio` para `parte`, mantendo o valor: não nasce segunda cobrança e a unicidade de uma cobrança por participação é preservada. Cobrança já `isenta` pela RN05 é reaberta como `pendente` de origem `parte`. Sem vaga, a reconfirmação cai na lista de espera (RN08) |
| RN26 | Cobrança vencida não bloqueia nenhuma ação: o devedor confirma presença e entra na lista de espera normalmente. O efeito é de visibilidade — o participante com débito vencido aparece marcado na lista de participantes do jogo, e essa marcação é vista apenas pelo criador do jogo, pelo recebedor e pelos admins do grupo. Os demais participantes não a veem, e o próprio devedor continua enxergando seu débito pela RF20 |

### Lista de espera

| ID | Regra |
| --- | --- |
| RN08 | Sem vaga, a confirmação coloca a pessoa em `lista_espera`, e `posicao_espera` registra a ordem de entrada apenas para exibição. A vaga liberada é anunciada a todos da lista ao mesmo tempo e fica com quem confirmar primeiro; os demais seguem na lista. Débito vencido não impede entrar na lista nem confirmar vaga livre (RN26). Anúncio feito perto do início vale até o início do jogo |

### Comprovantes

| ID | Regra |
| --- | --- |
| RN09 | A triagem automática classifica o comprovante como `consistente` quando o valor lido é igual ou maior que a cobrança, a data lida está entre o início do jogo e o envio, e o destinatário lido casa com o nome ou a chave Pix do credor. Falha em qualquer um desses pontos resulta em `divergente`; leitura impossível, em `ilegivel`. A leitura acontece no próprio aparelho, antes do upload, e não há modelo de visão de reserva: o que o reconhecimento de texto não extrair entra como `ilegivel`. A classificação, porém, é calculada no servidor a partir dos campos lidos e dos dados da cobrança, nunca enviada pronta pelo app. Nos três casos o envio é aceito, a cobrança passa a `comprovante_enviado` e o credor recebe o alerta: a baixa é sempre decisão dele |
| RN10 | O identificador da transação é único em toda a plataforma. Envio cujo identificador já exista é recusado, com aviso ao devedor de que aquele comprovante já foi usado. Comprovante sem identificador legível é aceito como `ilegivel` e não participa dessa checagem |
| RN19 | Só o devedor e o credor daquela cobrança abrem o arquivo. A retenção é de um mês contado a partir do momento em que a cobrança deixa de estar ativa, seja por confirmação, isenção ou cancelamento; enquanto a cobrança estiver `pendente` ou `comprovante_enviado`, o arquivo é mantido sem prazo. Depois da baixa, o devedor pode apagar o próprio comprovante (RF37). O descarte apaga o arquivo e esvazia `arquivo_url`, mas preserva a linha de Comprovante com os dados lidos, porque `id_transacao` segue bloqueando reenvio (RN10) e a cobrança segue confirmada |

### Grupos, papéis e herança

| ID | Regra |
| --- | --- |
| RN11 | As regras do grupo são consultadas no grupo, não copiadas no jogo. A alteração passa a valer de imediato para os jogos já abertos, exceto onde o jogo tenha sobrescrito o campo (RN12). Todos os confirmados recebem notificação dizendo o que mudou; não há reabertura de prazo de cancelamento por causa disso |
| RN12 | `local_padrao_id`, `vagas_padrao` e `custo_total_padrao` preenchem o formulário de criação como sugestão, e o jogo guarda o próprio valor. `prazo_cancelamento_horas` vem do grupo e pode ser sobrescrito no jogo; vazio significa seguir o grupo. No jogo avulso o prazo é obrigatório, assim como local, horário, vagas e custo |
| RN14 | Vale o preço por hora da quadra quando existir, senão o do local. O custo total é sugerido pelo preço por hora multiplicado pela duração e permanece editável pelo criador, porque o valor pago nem sempre é o de tabela. Sem preço cadastrado, o criador informa o custo total à mão. Preço por faixa de horário segue fora do MVP |
| RN15 | No modo `por_quadra`, escolher a quadra é obrigatório e o sistema impede criar dois jogos na mesma quadra em horários que se sobreponham. No modo `por_horario`, a quadra fica vazia e o sistema impede criar jogo quando o número de jogos simultâneos atingir a capacidade do local. Nos dois modos, o jogo precisa caber inteiro — início mais duração — dentro de uma faixa de funcionamento do local, senão é bloqueado. Faixa cujo `fecha` é menor ou igual ao `abre` atravessa a meia-noite e termina no dia seguinte: é assim que se cadastra a quadra aberta das 20h às 2h, caso comum do vôlei noturno. `capacidade` vazia significa local sem limite declarado: o sistema não checa simultaneidade e a responsabilidade pela reserva, feita fora do app, fica com o criador |
| RN18 | Reivindicação e verificação de local ficam fora do MVP. Locais, quadras, horários de funcionamento e preços são mantidos pelo desenvolvedor direto nas tabelas, pelo painel do banco: a política de linha nega escrita nessas três tabelas a qualquer cliente autenticado, e só a chave de serviço grava. O app oferece uma lista fechada na criação do jogo e nunca escreve nela. Não existe painel administrativo dentro do produto nem papel de admin de plataforma; as checagens da RN15 vivem no banco, não em tela. Os campos `dono_id` e `verificado` permanecem no modelo sem uso, à espera do perfil de dono de local |

A RN13 distribui as operações entre os papéis. Criador é quem criou o jogo, admin é quem administra o grupo, membro é quem participa dele.

| Operação | Quem pode |
| --- | --- |
| Editar e cancelar o jogo | Criador e admins do grupo |
| Marcar falta | Recebedor do jogo e admins do grupo |
| Dar baixa ou isentar cobrança | Somente o credor, que é quem recebe o Pix |
| Gerar ou revogar convite de grupo | Somente admins |
| Gerar convite de jogo | Qualquer participante confirmado |
| Editar as regras do grupo | Somente admins |
| Promover membro a admin | Quem criou o grupo |
| Definir ou trocar o recebedor do jogo | O criador, na criação e na edição até o encerramento (RN20, RN24) |
| Remover membro do grupo | Somente admins |
| Encerrar o jogo à mão | Criador e admins do grupo |
| Duplicar um jogo do grupo | Qualquer membro do grupo |
| Duplicar um jogo avulso | Somente o criador do jogo de origem |
| Manter locais, quadras e preços | Ninguém pelo app; o desenvolvedor, direto no banco (RN18) |

### Ciclo de vida do jogo

| ID | Regra |
| --- | --- |
| RN28 | Duplicar um jogo copia local, quadra, duração, vagas, custo total, recebedor e prazo de cancelamento da origem, pedindo apenas a nova data e o horário de início. A `chave_pix_recebedor` não é copiada do jogo antigo: é lida de novo do perfil do recebedor no momento da duplicação, para não propagar uma chave que ele já tenha trocado. Recebedor sem chave no perfil faz o formulário pedi-la, como na criação (RN24). Nenhuma participação ou cobrança é copiada e o jogo nasce `aberto`, sujeito também às checagens da RN15 |
| RN17 | O jogo passa a `encerrado` uma hora depois do fim do horário reservado, e o criador pode encerrá-lo à mão a partir desse fim. O encerramento libera o pagamento das cobranças (RN07) e congela a presença: a partir dele, só a marcação de falta é permitida (RN04). Quem restou em `lista_espera` mantém esse status, porque o jogo encerrado já diz que a espera terminou sem vaga e nenhuma cobrança nasceu para essas pessoas. As cobranças seguem ativas sem prazo final, aceitando comprovante, baixa e isenção |
| RN20 | Com confirmados no jogo, `vagas_total` não desce abaixo do número de confirmados e `custo_total` é editável com aviso e recálculo (RN01). Data, horário, local e quadra também são editáveis, com notificação a todos os confirmados e reabertura do cancelamento sem multa até o início do jogo: remarcar não pode punir quem não consegue mais ir. As janelas de edição são duas, e nenhuma ultrapassa o encerramento — é isso que garante que nenhum reajuste alcance cobrança já paga. `vagas_total` é editável até o início do jogo (RN06), porque depois disso ninguém mais entra e o número deixou de ter efeito. `custo_total` e o recebedor vão até o encerramento, porque o valor real da quadra e quem acabou pagando são coisas que muitas vezes só se sabem no local. Trocar o recebedor reescreve `chave_pix_recebedor` e migra o `credor_id` de todas as cobranças do jogo, inclusive as isentas e canceladas, para que o histórico do jogo aponte a um único credor |
| RN23 | O criador ou um admin cancela o jogo até o seu início; depois disso, o caminho é encerrar. Todas as cobranças ativas passam a `cancelada`, inclusive as multas de cancelamento tardio, porque sem jogo não há quadra paga a ressarcir. Não existe estado de devolução: o pagamento só é liberado no encerramento (RN07) e o cancelamento só é possível antes do início, logo nenhuma cobrança de jogo cancelado chegou a ser paga |

### Conta, membros e avisos

| ID | Regra |
| --- | --- |
| RN27 | A exclusão da conta é pedida pelo titular e recusada enquanto ele tiver cobrança `pendente` ou `comprovante_enviado`, como devedor ou credor; a tela informa o que falta resolver. Sem pendência, o usuário é apagado do serviço de autenticação — a credencial deixa de existir e o acesso se torna impossível — e o perfil que fica é anonimizado: o nome vira `Jogador removido`, e avatar, telefone e chave Pix são apagados. Não há valor anônimo a inventar, porque a credencial não mora no perfil. A `chave_pix_recebedor` copiada nos jogos do titular também é apagada — quando a exclusão é permitida, nenhuma cobrança aponta mais para ele, então a chave congelada não serve a ninguém e seria dado bancário órfão. Participações e cobranças encerradas permanecem, porque integram o histórico financeiro de terceiros. Admin único de um grupo promove outro admin antes de excluir a conta |
| RN30 | O membro sai do grupo quando quiser e um admin remove qualquer membro. A saída não apaga participações nem cobranças já existentes: em jogo futuro onde a pessoa esteja confirmada, vale o cancelamento normal, com multa se fora do prazo (RN02 e RN03). Quem criou o grupo só sai depois de promover outro admin. Sair não impede voltar por um novo convite |
| RN29 | Os avisos do sistema aparecem no app e, para quem autorizar, chegam também por push. Nenhuma regra depende de push entregue — o app sempre mostra o estado atual ao ser aberto, e o anúncio de vaga da RN08 segue válido até o início do jogo para quem não recebeu o aviso |

### Acesso e convites

| ID | Regra |
| --- | --- |
| RN21 | O acesso é por código de seis dígitos enviado ao e-mail informado. O e-mail é a credencial e vive no serviço de autenticação, não na tabela Pessoa; o telefone é contato opcional do perfil, sem unicidade e sem papel de acesso. Não há canal alternativo de entrega, porque o canal já é o e-mail: quem não recebe pede outro código. A troca de e-mail (RF35) é feita a partir da sessão ativa, confirmada nos dois endereços, e mantém conta, histórico e cobranças; e-mail que já pertence a outra conta bloqueia a troca |
| RN22 | O convite de grupo é um link multiuso, sem expiração, que o admin pode revogar preenchendo `revogado_em`; link revogado deixa de aplicar o convite e informa quem o abrir. O convite de jogo é multiuso e expira no início do jogo. Quem entra por convite de jogo participa somente daquele jogo, sem se tornar membro do grupo. Quem abre um convite sem ter conta conclui o cadastro e o convite é aplicado em seguida |

## Modelo de dados

Treze entidades. Valores monetários são inteiros em centavos. Todo identificador é UUID. Campos de auditoria (`criado_em`, `atualizado_em`) existem em todas as tabelas e não estão repetidos abaixo.

### Pessoa

Quem usa o sistema. A credencial de acesso é o e-mail, guardado pelo serviço de autenticação e fora desta tabela (RN21).

| Campo | Tipo | Obrigatório | Descrição |
| --- | --- | --- | --- |
| id | UUID | sim | Identificador; espelha o id do usuário no serviço de autenticação |
| nome | texto | sim | Nome de exibição |
| avatar\_url | texto | não | Foto de perfil |
| telefone | texto | não | Contato opcional, sem unicidade e sem papel de acesso (RN21) |
| chave\_pix | texto | não | Exibida a quem precisa pagar essa pessoa; obrigatória para ser recebedor de um jogo (RN24) |

### Grupo

Turma recorrente. Guarda os padrões que um novo jogo herda.

| Campo | Tipo | Obrigatório | Descrição |
| --- | --- | --- | --- |
| id | UUID | sim | Identificador |
| nome | texto | sim | Nome da turma |
| cor | texto | sim | Cor do selo no feed |
| criado\_por | UUID | sim | Referência a Pessoa |
| local\_padrao\_id | UUID | não | Referência a Local |
| vagas\_padrao | inteiro | não | Sugerido ao criar um jogo |
| custo\_total\_padrao | inteiro | não | Em centavos |
| prazo\_cancelamento\_horas | inteiro | sim | Horas antes do início em que a multa passa a valer |

### MembroGrupo

Ligação entre pessoa e grupo. Uma pessoa participa de vários grupos.

| Campo | Tipo | Obrigatório | Descrição |
| --- | --- | --- | --- |
| id | UUID | sim | Identificador |
| grupo\_id | UUID | sim | Referência a Grupo |
| pessoa\_id | UUID | sim | Referência a Pessoa |
| papel | enum | sim | `admin` ou `membro` |
| entrou\_em | data e hora | sim | Momento da entrada |

Único por par grupo e pessoa.

### Convite

Link compartilhável que dá acesso a um grupo ou a um jogo.

| Campo | Tipo | Obrigatório | Descrição |
| --- | --- | --- | --- |
| id | UUID | sim | Identificador |
| token | texto | sim | Único; compõe a URL |
| tipo | enum | sim | `grupo` ou `jogo` |
| grupo\_id | UUID | não | Preenchido quando o tipo é grupo |
| jogo\_id | UUID | não | Preenchido quando o tipo é jogo |
| criado\_por | UUID | sim | Referência a Pessoa |
| expira\_em | data e hora | não | Vazio significa sem prazo; no convite de jogo, o início do jogo (RN22) |
| revogado\_em | data e hora | não | Preenchido quando um admin revoga o link; vazio significa ativo (RF32, RN22) |

### Local

O estabelecimento. No MVP é cadastrado pelo desenvolvedor e oferecido em lista fechada (RN18); `criado_por` registra quem fez o cadastro.

| Campo | Tipo | Obrigatório | Descrição |
| --- | --- | --- | --- |
| id | UUID | sim | Identificador |
| nome | texto | sim | Nome do espaço |
| endereco | texto | não | Endereço legível |
| latitude | decimal | não | Coordenada |
| longitude | decimal | não | Coordenada |
| telefone | texto | não | Contato |
| criado\_por | UUID | sim | Referência a Pessoa |
| dono\_id | UUID | não | Sem uso no MVP; reservado ao perfil de dono de local |
| verificado | booleano | sim | Sempre falso no MVP (RN18) |
| modo\_reserva | enum | sim | `por_quadra` ou `por_horario` |
| preco\_hora | inteiro | não | Em centavos; vale quando a quadra não define o seu |
| capacidade | inteiro | não | Jogos simultâneos suportados; vazio significa sem limite declarado (RN15) |

### HorarioFuncionamento

Faixas de abertura do local. Um dia pode ter mais de uma faixa.

| Campo | Tipo | Obrigatório | Descrição |
| --- | --- | --- | --- |
| id | UUID | sim | Identificador |
| local\_id | UUID | sim | Referência a Local |
| dia\_semana | inteiro | sim | 0 a 6, começando no domingo; é o dia em que a faixa **abre** |
| abre | hora | sim | Início da faixa |
| fecha | hora | sim | Fim da faixa; menor ou igual a `abre` significa que termina no dia seguinte (RN15) |

A convenção de meia-noite existe porque jogo noturno é o caso comum: a quadra aberta das 20h às 2h de sábado é uma faixa só, com `dia_semana` igual a sábado, `abre` 20:00 e `fecha` 02:00. Partir em duas faixas bloquearia um jogo das 23h à 1h, que não caberia em nenhuma delas.

### Quadra

Espaço individual dentro de um local. Opcional quando o local aluga apenas o horário.

| Campo | Tipo | Obrigatório | Descrição |
| --- | --- | --- | --- |
| id | UUID | sim | Identificador |
| local\_id | UUID | sim | Referência a Local |
| nome | texto | sim | Identificação, como Quadra 2 |
| tipo | enum | sim | `areia`, `ginasio` ou `outro` |
| preco\_hora | inteiro | não | Vazio usa o preço do local |

### Jogo

O encontro marcado. Pertence a um grupo ou é avulso.

| Campo | Tipo | Obrigatório | Descrição |
| --- | --- | --- | --- |
| id | UUID | sim | Identificador |
| grupo\_id | UUID | não | Vazio indica jogo avulso |
| criador\_id | UUID | sim | Referência a Pessoa |
| recebedor\_id | UUID | sim | Quem pagou a quadra e recebe os rateios |
| chave\_pix\_recebedor | texto | não | Chave do recebedor congelada quando ele foi definido; pode ter sido digitada pelo criador (RN24). Nunca nasce vazia: só esvazia na anonimização do recebedor (RN27) |
| local\_id | UUID | sim | Referência a Local |
| quadra\_id | UUID | não | Vazio quando o local aluga por horário |
| inicio | data e hora | sim | Início do jogo |
| duracao\_minutos | inteiro | sim | Duração reservada |
| vagas\_total | inteiro | sim | Jogadores permitidos |
| custo\_total | inteiro | sim | Em centavos; sugerido pelo preço do local |
| preco\_por\_vaga | inteiro | sim | custo\_total dividido por vagas\_total |
| prazo\_cancelamento\_horas | inteiro | não | Vazio usa a regra do grupo; obrigatório se avulso |
| status | enum | sim | `aberto`, `cancelado` ou `encerrado` |

O prazo sem multa não é armazenado: resulta de `inicio` menos `prazo_cancelamento_horas` — do jogo quando preenchido, do grupo quando vazio. O percentual de multa saiu do modelo: pela RN03, o cancelamento tardio paga a vaga inteira.

### Participacao

Vínculo entre pessoa e jogo, com o estado da presença.

| Campo | Tipo | Obrigatório | Descrição |
| --- | --- | --- | --- |
| id | UUID | sim | Identificador |
| jogo\_id | UUID | sim | Referência a Jogo |
| pessoa\_id | UUID | sim | Referência a Pessoa |
| status | enum | sim | `confirmado`, `lista_espera`, `cancelou_no_prazo`, `cancelou_fora_do_prazo` ou `faltou` |
| confirmado\_em | data e hora | não | Momento da confirmação |
| cancelado\_em | data e hora | não | Momento do cancelamento |
| posicao\_espera | inteiro | não | Ordem na lista de espera |

Único por par jogo e pessoa.

### Cobranca

O valor devido por um participante. Existe no máximo uma por participação; muda de origem conforme o desfecho.

| Campo | Tipo | Obrigatório | Descrição |
| --- | --- | --- | --- |
| id | UUID | sim | Identificador |
| participacao\_id | UUID | sim | Único; referência a Participacao |
| devedor\_id | UUID | sim | Referência a Pessoa |
| credor\_id | UUID | sim | O recebedor do jogo; migra junto quando o recebedor é trocado (RN20) |
| valor | inteiro | sim | Em centavos |
| origem | enum | sim | `parte`, `cancelamento_tardio` ou `falta` |
| status | enum | sim | `pendente`, `comprovante_enviado`, `confirmado`, `isenta` ou `cancelada` |
| confirmado\_por | UUID | não | Quem resolveu a cobrança, por baixa ou por isenção manual; vazio nas transições automáticas (RN07) |
| confirmado\_em | data e hora | não | Momento dessa resolução; preenchido junto com `confirmado_por` (RN07) |

### Comprovante

Tentativa de quitar uma cobrança. Uma cobrança pode receber várias.

| Campo | Tipo | Obrigatório | Descrição |
| --- | --- | --- | --- |
| id | UUID | sim | Identificador |
| cobranca\_id | UUID | sim | Referência a Cobranca |
| arquivo\_url | texto | não | Imagem ou PDF enviado; esvazia no descarte pela retenção ou por apagamento do devedor (RN19, RF37) |
| enviado\_em | data e hora | sim | Momento do envio |
| valor\_lido | inteiro | não | Extraído da imagem |
| data\_lida | data e hora | não | Extraída da imagem |
| destinatario\_lido | texto | não | Extraído da imagem |
| id\_transacao | texto | não | Único; bloqueia reenvio do mesmo comprovante |
| resultado | enum | sim | `consistente`, `divergente` ou `ilegivel` |

### Notificacao

Um aviso dirigido a uma pessoa. Alimenta o sino do app e é a origem do push (RN29). Só o destinatário a lê.

| Campo | Tipo | Obrigatório | Descrição |
| --- | --- | --- | --- |
| id | UUID | sim | Identificador |
| pessoa\_id | UUID | sim | Destinatário; referência a Pessoa |
| tipo | enum | sim | `vaga_liberada`, `jogo_editado`, `jogo_cancelado`, `regra_grupo_alterada`, `valor_recalculado`, `pagamento_liberado`, `cobranca_vencida`, `comprovante_recebido`, `comprovante_recusado`, `cobranca_confirmada`, `cobranca_isenta`, `falta_marcada`, `removido_do_grupo` ou `promovido_a_admin` |
| titulo | texto | sim | Linha exibida no sino |
| corpo | texto | não | Detalhe do que mudou |
| jogo\_id | UUID | não | Destino do toque, quando o aviso é de jogo |
| cobranca\_id | UUID | não | Destino do toque, quando o aviso é de cobrança |
| lida\_em | data e hora | não | Vazio significa não lida |

O aviso é sempre gravado, mesmo quando a pessoa não autorizou push ou o envio falha: pela RN29 nenhuma regra depende de entrega, e o sino é a fonte de verdade.

### DispositivoPush

Autorização de push de um aparelho. Uma pessoa pode ter vários, um por aparelho.

| Campo | Tipo | Obrigatório | Descrição |
| --- | --- | --- | --- |
| id | UUID | sim | Identificador |
| pessoa\_id | UUID | sim | Referência a Pessoa |
| token\_fcm | texto | sim | Único; endereço do aparelho no serviço de push |
| modelo\_aparelho | texto | não | Identificação do aparelho, para a pessoa reconhecer a sessão |
| ultimo\_erro\_em | data e hora | não | Marca o token expirado, que a rotina descarta |

A troca de e-mail e a exclusão de conta apagam todos os dispositivos do titular, não os de um aparelho específico: são os dois casos de revogação da RNF07, e em ambos o push deve parar em todo lugar. Por isso o modelo não precisa conhecer sessão, que fica como detalhe da stack de autenticação.

## Relacionamentos

O diagrama completo das treze entidades, com todos os campos, chaves estrangeiras, restrições de unicidade e invariantes, está em [modelo-de-dados.md](modelo-de-dados.md). Esta seção registra apenas o que a estrutura significa.

Pessoa é o centro do grafo: além de membro de grupo, ela aparece em Jogo, Participacao, Cobranca e Local como criador, recebedor, participante, devedor, credor ou cadastrante. Toda cobrança nasce de uma participação em um jogo — esse é o caminho que sustenta o rateio.

Duas restrições de unicidade garantem essa integridade: uma pessoa tem no máximo uma Participacao por jogo, e uma Participacao tem no máximo uma Cobranca. Juntas, elas impedem que a mesma vaga seja cobrada duas vezes.

Notificacao e DispositivoPush ficam à parte do grafo do rateio: pendem apenas de Pessoa e servem à entrega de avisos (RN29).

O fechamento das regras não mudou a estrutura do domínio: seguem as mesmas chaves estrangeiras e as mesmas cardinalidades. Mudaram atributos dentro das caixas. Pessoa perdeu `email` e `admin_plataforma` — a credencial passou a viver no serviço de autenticação e a base de locais saiu do app (RN18, RN21) — e seu `telefone` deixou de ser credencial para virar contato opcional; PushSubscription virou DispositivoPush, trocando as chaves do push de navegador por um token de aparelho; Grupo e Jogo perderam `multa_percentual`; Jogo ganhou `chave_pix_recebedor`; o enum de status de Participacao perdeu `convidado`, que nenhum fluxo usava — os convites são sempre por link (RN22), e quem abre um confirma ou entra na fila. O enum de status de Cobranca não ganhou `devolucao_pendente`: o estado foi descartado porque o congelamento da RN07 e o limite de cancelamento da RN23 tornam impossível um jogo cancelado ter cobrança paga. A ligação de Local com Pessoa pelo `dono_id` permanece declarada e sem uso enquanto a RN18 estiver fora do MVP.

## Requisitos não funcionais

O MVP trata dado pessoal e dado bancário de terceiros. Esta seção fixa o que disso trava implementação; desempenho, disponibilidade e backup ficam para o documento de arquitetura.

### Dado pessoal e LGPD

| ID | Requisito |
| --- | --- |
| RNF01 | São dados pessoais no sistema: e-mail, nome, foto de perfil, chave Pix, comprovante de pagamento e o telefone de quem optar por informá-lo. A base legal é a execução do serviço pedido pelo titular; não há uso para marketing nem compartilhamento com terceiros. A localização do aparelho, usada para ordenar a busca de locais por proximidade (RF28), é lida no momento da consulta, com permissão do sistema, e não é armazenada nem associada à conta. A imagem do comprovante é lida dentro do aparelho (RN09), então nenhum dado bancário de terceiro trafega para serviço de leitura externo |
| RNF02 | O comprovante é o dado mais sensível, porque carrega nome, instituição e identificador de transação de duas pessoas. Só o devedor e o credor daquela cobrança o acessam (RN19), por URL assinada de validade curta sobre arquivo privado, nunca por link público |
| RNF03 | A retenção do comprovante é de um mês após a cobrança deixar de estar ativa, por confirmação, isenção ou cancelamento (RN19), aplicada pela rotina periódica do banco. O descarte apaga o arquivo e esvazia `arquivo_url`, preservando a linha e o `id_transacao`. O devedor pode apagá-lo antes disso, depois da baixa (RF37) |
| RNF04 | A exclusão de conta anonimiza o titular e preserva o histórico financeiro de terceiros, nos termos da RN27. A anonimização alcança as cópias: a `chave_pix_recebedor` congelada nos jogos do titular é apagada junto, porque dado bancário duplicado não pode sobreviver ao pedido de exclusão |
| RNF05 | O titular exporta seus próprios dados em arquivo legível quando pedir. No MVP o atendimento é manual, pelo desenvolvedor, dentro de quinze dias |

### Acesso e integridade

| ID | Requisito |
| --- | --- |
| RNF06 | O código de seis dígitos vale cinco minutos e só uma vez, com limite de envios por e-mail a cada hora. A exigência é atendida pela configuração do serviço de autenticação, que também é quem guarda o código como hash: o produto não implementa geração, hash nem contagem de tentativas |
| RNF07 | A sessão é um par de credenciais do serviço de autenticação: um token curto, renovado por um token de validade longa. A troca de e-mail e a exclusão de conta encerram todas as sessões do titular, em todo aparelho |
| RNF08 | Toda data e hora de regra usa o horário do servidor em horário de Brasília, nunca o do aparelho (RN02). O armazenamento é em UTC e a conversão acontece na borda |
| RNF09 | A disputa pela vaga é resolvida no banco, em transação, travando a linha do jogo e contando os confirmados no momento da escrita. Duas confirmações simultâneas para a última vaga não podem gerar dois confirmados; a perdedora cai na lista de espera (RN08) |
| RNF10 | Confirmar presença, cancelar, dar baixa e enviar comprovante são idempotentes por requisição: o toque repetido, ou o reenvio após falha de rede, não gera segunda participação, segunda cobrança nem segunda baixa |
| RNF11 | O VoleiIn é um aplicativo Android nativo, com layout de celular. Não há versão web, instalação na tela de início nem suporte a iOS no MVP |
| RNF12 | O MVP é dimensionado para um piloto: um a três grupos conhecidos, até algumas dezenas de pessoas e poucos jogos por semana. A premissa autoriza a stack a otimizar velocidade de entrega e custo baixo em vez de cache, fila e escala horizontal. Não há mais custo variável por evento — a entrega do código e a leitura do comprovante deixaram de ser pagas. O que precisa de atenção nesse volume é a cota dos planos gratuitos: tamanho do banco, espaço de arquivos, tráfego de saída e a pausa do projeto após uma semana sem atividade |

## Decisões técnicas

A stack está definida: Flutter no cliente, Supabase no servidor, tudo em plano gratuito. O detalhe de cada camada, o mapa de onde cada regra mora e a ordem de implementação estão em [stack.md](stack.md). Esta seção registra o que as regras exigem da arquitetura.

| Tema | Decisão | Consequência |
| --- | --- | --- |
| Entrega do código de acesso | Código de seis dígitos por e-mail, pelo serviço de autenticação, com SMTP gratuito | Sem conta business, sem template aprovado pela Meta e sem custo por mensagem. Em troca, o e-mail passa a ser a credencial e o telefone deixa de autenticar (RN21) |
| Avisos do sistema | Sino no app e push de aplicativo, sem WhatsApp | O sino é a fonte de verdade e o push é entrega oportunista; nenhuma regra depende de entrega garantida (RN29) |
| Leitura do comprovante | Reconhecimento de texto no próprio aparelho, sem modelo de visão | Custo zero por comprovante e imagem que não sai do aparelho para ser lida. Em troca, o que o aparelho não reconhecer entra direto como `ilegivel`, e a classificação é recalculada no servidor para não depender do que o app afirma (RN09) |
| Regras de dinheiro | Funções no próprio banco, chamadas pelo app | Não existe servidor de aplicação a manter. Cálculo, transição de estado e hora de regra ficam onde está a transação, o que é o que sustenta RNF08, RNF09 e RNF10 |
| Arquivos | Armazenamento do Supabase, em espaço privado | Acesso controlado por política de linha e URL assinada, o que atende RN19 e RNF02 sem código próprio |
| Rotinas automáticas | Agendador dentro do banco, uma varredura por minuto | Um procedimento roda a cada minuto e trata o que venceu: encerramento do jogo (RN17), vencimento da cobrança (RN07), fim da janela de falta (RN04), descarte de comprovante (RNF03) e remoção de token de push já rejeitado. Sem host para manter. Expiração e revogação de convite ficam de fora: são comparações feitas na hora em que o link é aberto, não precisam de varredura. O estado vive no banco, então uma queda atrasa, não perde |
| Base de locais | Mantida pelo desenvolvedor direto nas tabelas | Nenhuma tela de administração para construir; em troca, as checagens da RN15 precisam viver no banco, porque não há formulário que as aplique (RN18) |

## Decisões e exclusões

### Decisões tomadas

| Tema | Decisão | Motivo |
| --- | --- | --- |
| Valor por vaga | Custo total dividido pelas vagas totais; alterar custo ou vagas recalcula as cobranças do jogo, com aviso | Permite corrigir o jogo sem recriá-lo. Não existe o caso de quem já pagou, porque o pagamento só abre no encerramento (RN07) |
| Vagas ociosas | Absorvidas pelo recebedor, que pode reduzir as vagas até o número de confirmados antes do início | Cobrar os presentes pela vaga vazia faria a quadra ser paga duas vezes; diluir o custo passa a ser decisão de quem paga |
| Substituição | A multa é perdoada quando a lista de espera assume a vaga | A quadra já foi paga por quem entrou; manter a multa seria cobrança em dobro |
| Momento do pagamento | Sempre após o jogo | Elimina a necessidade de reembolso para quem cancela dentro do prazo |
| Regras do grupo | Consultadas no grupo, não copiadas no jogo | Permite corrigir uma regra sem recriar jogos; exige aviso a quem já confirmou (RN11) |
| Recebimento | Pix direto ao credor, com baixa manual ou por comprovante | Evita contratar gateway e assumir responsabilidade financeira no MVP |
| Comprovante | Leitura automática serve como triagem, não como prova | Uma imagem pode ser editada e não comprova crédito em conta |
| Local | Cadastrado pelo desenvolvedor, em lista fechada | A base inicial é pequena e dispensa moderação; o perfil de dono fica para depois |
| Multa | Cancelamento tardio paga a vaga inteira, sem percentual configurável | Um número a menos para o admin decidir e para a tela explicar |
| Pagamento | Liberado no encerramento do jogo, com vencimento em 24 horas | Evita comprovante antes da hora e dá um momento único para abrir todas as cobranças |
| Estrutura de grupos | Feed pessoal com selo de origem, em vez de navegação por grupo | Reflete quem joga em várias turmas da cidade |
| Inadimplência | Marca visível ao criador, ao recebedor e aos admins, sem bloquear ninguém | O grupo é uma turma que se conhece; bloquear a vaga deixa a quadra mais vazia e resolve menos que uma conversa |
| Reconfirmação | Quem cancelou tarde volta pela mesma cobrança, que troca de origem | O valor é o mesmo nos dois casos, então reabrir é mais simples que punir e deixa a vaga ocupada |
| Repetir jogo | Botão de duplicar, em vez de recorrência automática | Resolve quase todo o incômodo da turma semanal sem entidade nova, feriado nem cancelamento de série |
| Chave Pix | Exigida de quem for recebedor, na criação do jogo | Pede o dado bancário só de quem recebe, e no momento em que ele faz falta |
| Reajuste de valor | Atualiza a cobrança existente; nunca cria uma segunda | Como o pagamento só é liberado no encerramento, não existe cobrança paga para reajustar. Mantém uma cobrança por participação sem exceção |
| Chave do recebedor | Congelada no jogo, não gravada no perfil de terceiro | Permite ao criador indicar quem recebe sem editar dado bancário de outra pessoa, e preserva a chave que foi exibida aos devedores |
| Janela de pagamento | Nada acontece com a cobrança antes do encerramento, nem baixa nem isenção manual | Dá um único momento em que o dinheiro começa a andar, o que elimina o estado de devolução e simplifica o reajuste |
| Avisos | Entidade própria, gravada sempre, com assinatura de push separada | O sino é a fonte de verdade e o push é entrega oportunista, como a RN29 já exigia |
| Base de locais | Mantida direto nas tabelas, sem painel no produto | A base é pequena e o piloto tem um só administrador; uma tela de cadastro custaria mais trabalho do que o erro de digitação que evitaria. As checagens da RN15 ficam no banco, onde valem para qualquer caminho de escrita |
| Plataforma | Aplicativo Android nativo em Flutter, sem iOS no piloto | O iOS exigiria anuidade de desenvolvedor e um Mac para compilar, para alcançar a minoria da turma inicial. A decisão é revisível sem mexer em regra nenhuma |
| Credencial | E-mail com código de seis dígitos, em vez de telefone por WhatsApp | A mensagem de WhatsApp cobra por envio e exige conta business verificada; o e-mail é gratuito nas cotas que o piloto usa. O telefone continua no perfil, mas como contato |
| Leitura do comprovante | Reconhecimento de texto no aparelho, sem modelo de visão | Era o último custo por evento. Ler no aparelho também mantém a imagem, que é o dado mais sensível do sistema, fora de serviço de terceiro |

### Fora do MVP

Processamento de pagamento pela plataforma, com baixa automática. Exige provedor Pix, custo por transação e responsabilidade regulatória. O modelo atual já comporta a mudança sem alteração estrutural.

Agenda e reserva de quadra pelo app. Hoje a reserva é feita fora da plataforma e apenas registrada. Quando entrar, surge uma entidade Reserva ligada ao Jogo.

Cadastro e reivindicação de locais pelos usuários. No MVP o desenvolvedor mantém a base de locais, quadras e preços; `dono_id` e `verificado` já estão no modelo para quando o perfil de dono existir.

Preço por faixa de horário. Pico e fora de pico ficam para quando o empresário gerir o próprio catálogo.

Jogo recorrente automático. O grupo define o horário fixo e o sistema cria os jogos sozinho. Exige entidade de série, tratamento de feriado e cancelamento em lote; a duplicação de jogo (RF34) cobre o caso comum por enquanto.

Reputação de jogadores. Pode ser calculada a partir do histórico de Participacao, com a origem `falta` das cobranças (RN04) como insumo, sem entidade nova.

Chat interno. O WhatsApp segue sendo o canal de conversa; o app entra pelo link compartilhado no grupo.

Aplicativo iOS. O piloto roda em Android, porque publicar na App Store custa uma anuidade e exige um Mac para compilar. Nada no modelo nem nas regras depende da plataforma, então entrar no iOS é trabalho de empacotamento, não de produto. Enquanto isso, quem tem iPhone acompanha pelo grupo de WhatsApp da turma, como hoje.

WhatsApp como canal do sistema, para o código de acesso ou para os avisos. Sai por custo por mensagem e por exigir conta business verificada. Volta à mesa se a entrega por e-mail se mostrar ruim no piloto: o modelo não muda, porque a credencial é um campo do serviço de autenticação e o aviso já é entidade própria (RN29).

Painel administrativo de locais. A manutenção da base é feita pelo desenvolvedor direto nas tabelas (RN18). Uma tela própria só se justifica quando existir mais de um administrador ou o perfil de dono de local.
