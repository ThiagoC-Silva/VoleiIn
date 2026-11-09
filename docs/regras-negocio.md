# Regras de Negócio
 
## 1. Glossário
 
| Termo | Definição |
|-------|-----------|
| **Grupo** | Conjunto de membros que organizam jogos juntos. |
| **Admin do grupo** | Membro que aprova entradas, remove membros, gerencia admins e pode excluir o grupo. Não tem poder sobre os jogos (RN15). |
| **Jogo de grupo** | Jogo criado dentro de um grupo por um membro. |
| **Jogo avulso** | Jogo criado fora de qualquer grupo. |
| **Admin do jogo** | Usuário que edita, cancela e conclui o jogo, gerencia a lista e marca faltas. |
| **Recebedor** | Participante que pagou o espaço e recebe todos os valores do jogo. |
| **Lista de presença** | Participantes confirmados, ordenados por ordem de entrada. |
| **Participante** | Usuário que está na lista de presença. |
| **Lista de espera** | Usuários avisados quando abre uma vaga. Não dá prioridade sobre ela. |
| **Limite de vagas** | Número máximo de participantes. É também o divisor do rateio. |
| **Prazo de cancelamento** | Data e hora até as quais o cancelamento não gera multa. |
| **Cancelamento** | Saída da lista antes do início do jogo. |
| **Falta** | Saída da lista entre o início e o fim do jogo, ou ausência marcada pelo admin na conclusão. |
| **Multa** | Valor a pagar gerado por cancelamento fora do prazo ou por falta. É igual à parte por vaga. |
| **Isenção** | Anulação de uma multa, automática (RN62, sem gerar valor a pagar) ou manual (RN66, o valor passa para Isento). |
| **Parte por vaga** | Valor total ÷ limite de vagas, arredondado para cima ao centavo. |
| **Vaga coberta** | Vaga paga por alguém: ocupada por um participante (presente ou faltoso com multa) ou compensada por uma multa de cancelamento mantida. A vaga do recebedor conta como coberta. |
| **Valor a pagar** | Débito de um usuário com o recebedor de um jogo concluído. |
| **Comprovante** | Imagem ou PDF do Pix enviado para quitar um valor a pagar. |
| **Compartilhar contexto** | Ter em comum com outro usuário um grupo atual ou qualquer jogo, atual ou passado, na lista de presença ou de espera (RN107). |
 
## 2. Datas, horas e valores
 
| ID | Regra | RF |
|----|-------|----|
| RN01 | O app usa um **fuso único: `America/Fortaleza`**. Instantes são gravados em UTC (`timestamptz`) e exibidos nesse fuso. Os horários fixos (lembretes de 9h e 20h) também usam esse fuso. | RF96 |
| RN02 | Toda comparação de tempo ("dentro do prazo", "antes do início") usa o **relógio do servidor** no momento em que a operação é gravada, nunca o do aparelho. | RF50, RF55, RF56 |
| RN03 | **Limites de corte:** o cancelamento é *no prazo* se ocorrer em um instante **≤** prazo. Entradas e cancelamentos são aceitos enquanto o instante for **<** início. | RF55, RF56, RF57 |
| RN04 | Dinheiro é armazenado em **centavos inteiros**. Nenhum cálculo usa ponto flutuante. | RF67 |
| RN05 | **Valor total:** livre, sem teto, com o mínimo técnico de 1 centavo (maior que zero). | RF29 |
| RN06 | **Limite de vagas:** livre, sem teto, com o mínimo técnico de 1 vaga. | RF26 |
 
## 3. Grupos e papéis
 
| ID | Regra | RF |
|----|-------|----|
| RN10 | O criador do grupo torna-se admin. O grupo pode ter vários admins, e qualquer admin pode promover membros e rebaixar outros admins. | RF14, RF23 |
| RN11 | O grupo tem um código de convite longo e aleatório, válido até um admin invalidá-lo ou regenerá-lo. Regenerar invalida o código anterior, e as solicitações já criadas não são afetadas. | RF15 |
| RN12 | Entrar pelo convite gera uma solicitação pendente. O usuário tem no máximo uma solicitação pendente por grupo. Após uma recusa, pode solicitar de novo. | RF16, RF17 |
| RN13 | O grupo sempre tem ao menos um admin. O último admin só sai ou é rebaixado depois de promover outro. Se for o único membro, ele exclui o grupo (RN17). | RF24, RF103 |
| RN14 | Quem sai ou é removido do grupo: | RF20, RF21, RF22 |
|      | 1. é retirado das listas de presença e de espera de **todos** os jogos do grupo **ainda não iniciados**, inclusive daqueles em que entrou pelo link, **sem multa em nenhum momento**, mesmo após o prazo de cancelamento. Se quiser, pode voltar pelo link do jogo; | |
|      | 2. deixa de ser admin dos jogos do grupo Aberto ou Confirmado (se for o único admin, a saída é bloqueada pela RN16); | |
|      | 3. não tem alteração nos jogos já iniciados ou concluídos nem nos valores em aberto. | |
| RN15 | O admin do grupo **não tem poder sobre os jogos** do grupo. Editar, cancelar, concluir e gerenciar a lista são ações exclusivas dos admins do jogo. | RF26, RF34 |
| RN16 | A saída e a remoção do grupo ficam **bloqueadas** enquanto o usuário for recebedor ou único admin de um jogo do grupo Aberto ou Confirmado. Antes, é preciso indicar outro. | RF22, RF35 |
| RN17 | **Exclusão do grupo:** um admin pode excluir o grupo se não houver jogo do grupo Aberto ou Confirmado. O grupo é arquivado: membros e solicitações pendentes são removidos, o convite é invalidado e os membros são notificados. Os jogos concluídos e cancelados, os valores e os comprovantes continuam no histórico de quem participou. | RF103, RF104 |
 
## 4. Jogo
 
### 4.1 Criação e dados
 
| ID | Regra | RF |
|----|-------|----|
| RN20 | Um membro do grupo pode criar um jogo no grupo. Qualquer usuário autenticado pode criar um jogo avulso. | RF26, RF27 |
| RN21 | Ao criar o jogo, o criador torna-se o **único admin**, o **recebedor** e o **primeiro da lista de presença**. | RF26, RF31 |
| RN22 | Como o criador é o recebedor padrão, **criar um jogo exige chave Pix cadastrada**. Sem ela, o app pede o cadastro antes de concluir a criação. | RF32 |
| RN23 | Na criação e na edição valem: prazo de cancelamento ≤ início < fim, com o início no futuro na criação. O nome do local é obrigatório e o link do Google Maps é opcional. | RF26, RF28, RF30 |
| RN24 | A estimativa por pessoa (valor total ÷ limite) é apenas informativa e não gera cobrança. | RF29 |
 
### 4.2 Admins do jogo
 
| ID | Regra | RF |
|----|-------|----|
| RN25 | Um admin do jogo pode adicionar e remover outros admins. O jogo sempre tem ao menos um admin, em qualquer status, inclusive Concluído e Cancelado: depois da conclusão, o admin ainda isenta multas (RN66) e troca o recebedor (RN31). | RF34, RF35 |
| RN26 | **Ser admin não depende de estar na lista.** Sair da lista não tira o papel de admin. O único admin só deixa o papel depois de indicar outro. A exceção é a saída do grupo (RN14). | RF35 |
| RN27 | Só pode ser indicado como admin quem está na lista de presença do jogo. | RF34 |
 
### 4.3 Recebedor
 
| ID | Regra | RF |
|----|-------|----|
| RN28 | O jogo tem exatamente um recebedor, que **precisa estar na lista de presença** e **ter chave Pix**. | RF31, RF32 |
| RN29 | O recebedor **não sai da lista** (cancelando ou após o início) nem é removido por um admin até que outro participante da lista, com chave Pix, seja definido como recebedor. Se não houver candidato, resta ao admin cancelar o jogo. | RF33, RF50, RF54 |
| RN30 | Antes da conclusão, um admin do jogo pode trocar o recebedor livremente. | RF33 |
| RN31 | **Troca após a conclusão:** é permitida, com estas regras: | RF33 |
|      | 1. A troca fica **bloqueada enquanto houver valor Em análise** no jogo. | |
|      | 2. Os valores **Pagos** continuam vinculados ao antigo recebedor. | |
|      | 3. Os valores **Pendentes** passam a ser devidos ao novo recebedor. | |
|      | 4. O valor a pagar do novo recebedor, se existir e estiver Pendente, passa para **Isento** (RN94). | |
|      | 5. O antigo recebedor passa a ter um valor Pendente, igual à parte por vaga, com o novo recebedor. Ele ocupava uma vaga e, como recebedor, não tinha multa nem valor a pagar. Se ele já tiver um valor Pago nesse jogo, de uma troca anterior, nada é criado, para que ninguém pague duas vezes pela mesma vaga. | |
|      | 6. O acerto entre os dois do que já foi recebido fica **fora do app**. | |
| RN32 | Cada valor a pagar guarda o recebedor a quem é devido. A validação de comprovantes (RN88) usa esse recebedor, não o recebedor atual do jogo. | RF71, RF80 |
 
### 4.4 Edição
 
| ID | Regra | RF |
|----|-------|----|
| RN33 | **Antes do início**, o admin pode editar todos os dados, respeitando a RN23 e a regra de que o limite não pode ficar abaixo do número de participantes. O novo início também precisa estar no futuro. | RF36, RF53 |
| RN34 | **Após o início**, nenhum dado é editável, exceto o valor total, e apenas no ato da conclusão manual. O limite de vagas fica congelado a partir do início. | RF36, RF40, RF41 |
| RN35 | Um cancelamento mantém a classificação (no prazo ou fora do prazo) que tinha no instante em que ocorreu, mesmo que o prazo seja alterado depois. | RF36, RF56 |
| RN36 | **A conclusão é definitiva.** Depois dela, nenhum dado do jogo, falta ou valor é recalculado. As correções possíveis são a isenção manual de multa (RN66), a marcação manual de pagamento (RN84) e a troca de recebedor (RN31). Erros no valor total se resolvem fora do app. | RF40, RF64 |
 
## 5. Estados do jogo
 
| Status | Significado | Final? |
|--------|-------------|--------|
| Aberto | Lista com vagas livres | Não |
| Confirmado | Lista cheia | Não |
| Cancelado | Jogo não acontece, sem rateio | Sim |
| Concluído | Rateio gerado | Sim |
 
"Em andamento" não é um status: é uma condição derivada (início ≤ agora e status não final), usada nas regras de saída e falta.
 
| ID | De → Para | Gatilho | RF |
|----|-----------|---------|----|
| RN40 | (criação) → Aberto ou Confirmado | Confirmado se o limite for 1, já que o criador entra na lista | RF37 |
| RN41 | Aberto → Confirmado | O número de participantes atinge o limite, por uma entrada ou pela redução do limite | RF38, RF53 |
| RN42 | Confirmado → Aberto | Uma vaga é liberada ou o limite é aumentado, sempre antes do início | RF38, RF52 |
| RN43 | Aberto/Confirmado → Cancelado | Um admin cancela, a qualquer momento até a conclusão | RF39 |
| RN44 | Aberto/Confirmado → Concluído | Conclusão manual por um admin, a partir do horário de fim | RF40 |
| RN45 | Aberto/Confirmado → Concluído | Conclusão automática **1 hora após o fim**, se não houver conclusão manual | RF42 |
 
### 5.1 Conclusão
 
| ID | Regra | RF |
|----|-------|----|
| RN46 | A conclusão manual e a automática usam a **mesma função** do servidor, em uma única transação. | RF40, RF42 |
| RN47 | **Conclusão manual:** o admin pode editar o valor total e marcar faltas. Por padrão, todos contam como presentes, exceto quem tem falta registrada pela saída após o início (RN57), que já vem marcado e pode ser desmarcado. | RF40, RF60 |
| RN48 | **Conclusão manual com vagas não cobertas:** o app mostra o valor que fica por conta do recebedor (RN74) antes de confirmar. O limite de vagas não pode ser alterado na conclusão (RN34). | RF41 |
| RN49 | **Conclusão automática:** mantém o valor total e o limite, não registra faltas novas e **mantém as faltas já registradas** pela saída após o início. | RF42 |
 
## 6. Lista de presença e lista de espera
 
| ID | Regra | RF |
|----|-------|----|
| RN50 | **Quem pode entrar:** em jogo de grupo, os membros do grupo e quem tem o link de convite do jogo. Em jogo avulso, apenas quem tem o link. | RF47, RF48 |
| RN51 | Entrar na **lista de presença** exige o jogo Aberto; entrar na **lista de espera** exige o jogo Confirmado. Nos dois casos, só antes do início. Quem já está na lista de espera continua nela se o jogo voltar a Aberto, e é avisado da vaga (RN53). Não se entra em jogos Cancelados ou Concluídos. | RF49, RF55 |
| RN52 | A ordem da lista é a ordem de entrada, pelo instante gravado no servidor. Essa ordem é usada no compartilhamento em texto. | RF100 |
| RN53 | **Vaga liberada** (cancelamento, remoção, saída do grupo ou aumento de limite) fica aberta a qualquer usuário com acesso, e fica com o primeiro que confirmar. A lista de espera **não tem prioridade**, apenas recebe o aviso. A disputa é resolvida no banco, com transação e bloqueio de linha. | RF51, RF52, RF90 |
| RN54 | Quem entra na lista de presença sai automaticamente da lista de espera. A lista de espera é encerrada no início do jogo. | RF49 |
| RN55 | O convite do jogo é **um código por jogo**, que qualquer participante pode compartilhar e um admin pode regenerar. | RF43 |
| RN56 | Se quem cancelou voltar à lista antes do início, o cancelamento anterior é **anulado** e não conta para multa. A pessoa volta com um novo instante de entrada (fim da ordem da lista), e um novo cancelamento vale como o primeiro. | RF50, RF57 |
| RN57 | **Saída antes do início** é um cancelamento: libera a vaga e registra a data e a hora. **Saída entre o início e o fim** registra a falta na hora e **não libera a vaga**. **Após o horário de fim**, a lista fica travada até a conclusão: ninguém sai, e novas faltas só são marcadas pelo admin na conclusão manual (RN47). | RF50, RF56 |
| RN58 | O admin do jogo só **remove participantes até o início**. A remoção não gera multa, libera a vaga e notifica o participante. O admin não pode remover a si mesmo: para sair, usa a saída normal (RN57). Após o início, o admin usa a falta e a isenção manual. | RF54, RF59, RF104 |
| RN59 | O limite pode ser aumentado até o início. Pode ser reduzido a qualquer momento antes do início, desde que não fique abaixo do número de participantes. | RF52, RF53 |
 
## 7. Cancelamentos, faltas e multas
 
| ID | Regra | RF |
|----|-------|----|
| RN60 | **Cancelamento no prazo** (instante ≤ prazo): sem multa e sem valor a pagar. | RF56 |
| RN61 | **Cancelamento fora do prazo** (prazo < instante < início): gera uma multa candidata, sujeita à isenção automática (RN62). | RF57 |
| RN62 | **Isenção automática** (calculada na conclusão, com a situação no instante do início): | RF58 |
|      | 1. `L` = **menor limite vigente** entre o prazo de cancelamento e o início (assim, um aumento de limite não gera multa). | |
|      | 2. `ociosas` = max(0, `L` − participantes no início). | |
|      | 3. `mantidas` = min(cancelamentos fora do prazo, `ociosas`). | |
|      | 4. Mantêm-se as multas dos **últimos** a cancelar. Os primeiros a cancelar são isentados e notificados. | |
| RN63 | **Falta:** registrada pela saída entre o início e o fim (RN57) ou marcada pelo admin na conclusão (RN47). Toda falta gera multa. | RF60, RF61 |
| RN64 | O valor de toda multa é igual à **parte por vaga** final do jogo (RN71). | RF62 |
| RN65 | Não geram multa: o recebedor (RF63), quem foi removido pelo admin (RN58), quem saiu do grupo (RN14) e quem excluiu a conta (RN104). | RF13, RF22, RF59, RF63 |
| RN66 | O admin do jogo pode isentar manualmente uma multa **enquanto o valor estiver Pendente**. O valor passa para **Isento** (RN93) e o participante é notificado. | RF64, RF104 |
| RN67 | Jogo cancelado não gera multas. | RF66 |
 
**Exemplo da RN62.** Jogo com 10 vagas, prazo às 18h e início às 20h. Ana (18h10), Bruno (18h30) e Davi (19h20) cancelam fora do prazo. Carla entra às 19h. O jogo começa com 8 participantes.
 
| Passo | Resultado |
|-------|-----------|
| `L` | 10 |
| `ociosas` | 10 − 8 = 2 |
| `mantidas` | min(3, 2) = 2 |
| Ana (1ª a cancelar) | **Isenta** |
| Bruno e Davi | Pagam multa |
 
## 8. Rateio
 
| ID | Regra | RF |
|----|-------|----|
| RN70 | O rateio é gerado **somente na conclusão**. Jogo cancelado não tem rateio. | RF40, RF66 |
| RN71 | **Parte por vaga** = ⌈valor total em centavos ÷ limite final⌉. O limite final é o limite vigente no início (RN34). | RF67 |
| RN72 | **Geram valor a pagar igual à parte por vaga:** cada participante presente, cada faltoso (multa) e cada cancelamento com multa mantida. **Não geram:** o recebedor, os isentos automaticamente e quem cancelou no prazo. | RF68 a RF71 |
| RN73 | Todos os valores a pagar são devidos ao recebedor e começam como **Pendente**. | RF71, RF72 |
| RN74 | **Valor por conta do recebedor** = valor total − soma dos valores a pagar não Isentos. Inclui a própria vaga dele e as vagas não cobertas. | RF41 |
| RN75 | A **sobra do arredondamento** (até limite − 1 centavos) fica com o recebedor. | RF67 |
| RN76 | O participante vê o próprio valor e status. O recebedor e os admins do jogo veem o rateio completo. | RF73, RF74 |
 
**Exemplo completo.** Valor total de R$ 250,00, limite de 12 vagas e recebedora Ana.
 
- Parte por vaga: ⌈25.000 ÷ 12⌉ = 2.084 centavos, ou seja, **R$ 20,84**.
- No início havia 10 participantes, incluindo Ana. Antes, Bruno, Carla e Davi cancelaram fora do prazo, nessa ordem.
- Isenção: `ociosas` = 12 − 10 = 2, então ficam mantidas as multas de Carla e Davi. Bruno é isento.
- Na conclusão, Edu é marcado como faltoso.
| Quem | Valor a pagar |
|------|---------------|
| 8 participantes presentes (exceto Ana e Edu) | 8 × R$ 20,84 |
| Edu (falta) | R$ 20,84 |
| Carla e Davi (multa de cancelamento) | 2 × R$ 20,84 |
| Ana (recebedora) e Bruno (isento) | R$ 0,00 |
| **Total a receber** | **11 × R$ 20,84 = R$ 229,24** |
 
Vagas cobertas: 10 participantes + 2 multas = 12. Por conta de Ana: R$ 250,00 − R$ 229,24 = R$ 20,76, que é a vaga dela já descontada a sobra de 8 centavos.
 
## 9. Pagamentos e comprovantes
 
### 9.1 Estados do valor a pagar
 
Status: **Pendente**, **Em análise**, **Pago** e **Isento**. O valor Isento fica visível no histórico, mas sai dos totais (RF75, RF76) e das cobranças.
 
| ID | De → Para | Gatilho | RF |
|----|-----------|---------|----|
| RN80 | Pendente → Pago | Comprovante validado automaticamente; o recebedor é notificado | RF82, RF104 |
| RN81 | Pendente → Em análise | Comprovante ilegível ou divergente, ou enviado após a 3ª leitura (RN86) | RF83 |
| RN82 | Em análise → Pago | O recebedor aprova | RF83 |
| RN83 | Em análise → Pendente | O recebedor recusa, com observação obrigatória | RF83 |
| RN84 | Pendente → Pago | O recebedor marca como pago manualmente, sem comprovante | RF84 |
| RN85 | Pago → Pendente | O recebedor reverte **apenas** um pagamento que ele mesmo marcou manualmente. O app registra quem e quando, e notifica. Pagamentos aprovados por comprovante não são revertidos. | RF85 |
| RN93 | Pendente → Isento | Um admin do jogo isenta uma multa (RN66). O app registra quem e quando | RF64 |
| RN94 | Pendente → Isento | Troca de recebedor após a conclusão: o valor do novo recebedor é anulado (RN31.4) | RF33 |
 
### 9.2 Envio e validação
 
| ID | Regra | RF |
|----|-------|----|
| RN86 | Um comprovante só pode ser enviado para valor **Pendente**. São até **3 leituras automáticas** por valor a pagar. Os envios seguintes vão direto para Em análise, sem chamar a API. Envios recusados por ID repetido contam como leitura. Se a API falhar (erro, tempo esgotado ou sem resposta), o comprovante vai para Em análise e a tentativa **não conta** como leitura. Enquanto uma leitura está em curso, o app não permite novo envio para o mesmo valor. | RF78 |
| RN87 | Tipos aceitos: imagem e PDF, com tamanho máximo de **10 MB**, validados no app e no servidor. | RF78 |
| RN88 | O comprovante é aprovado automaticamente somente se **todas** as condições abaixo forem verdadeiras. Se algum campo não puder ser lido, ele vai para Em análise. | RF80 |
|      | a) o **valor** é exatamente igual ao valor a pagar; | |
|      | b) o **destinatário** confere com o recebedor do valor (RN32): a chave Pix é igual à chave **atual** do recebedor, **ou** o nome normalizado (sem acentos, em maiúsculas) contém o primeiro e o último nome do recebedor; | |
|      | c) a **data e hora** do pagamento são iguais ou posteriores ao **início do jogo**, **comparadas no minuto**: a hora do comprovante é lida no horário de Brasília (`America/Sao_Paulo`) e o início do jogo é truncado ao minuto. Assim, quem paga logo ao fim da partida, antes da conclusão, é aprovado automaticamente. Pagamentos anteriores ao início vão para Em análise; | |
|      | d) o **ID da transação** não está em uso (RN89). | |
| RN89 | **ID repetido:** o envio é **recusado** se o ID já estiver em um comprovante **Aprovado ou Em análise** de outro valor a pagar, e o motivo é informado ao pagador. Se aquele comprovante for recusado, o ID volta a ficar livre. Unicidade garantida por restrição no banco. | RF81 |
| RN90 | Os estados do comprovante são Em análise, Aprovado e Recusado. O participante vê o status e a observação do recebedor. | RF86 |
 
### 9.3 Retenção
 
| ID | Regra | RF |
|----|-------|----|
| RN91 | O **arquivo** é apagado **30 dias após a decisão** sobre o comprovante: aprovação automática, aprovação ou recusa pelo recebedor, ou recusa por ID repetido. Só o arquivo é apagado: o **registro do comprovante fica guardado por completo** no histórico (dados lidos, resposta da leitura automática, resultado das conferências, status, decisão, observação do recebedor e ID da transação). | RF87 |
| RN92 | O comprovante Em análise não tem prazo de exclusão: o prazo só começa a contar após a decisão do recebedor. | RF87 |
 
## 10. Conta e dados pessoais
 
| ID | Regra | RF |
|----|-------|----|
| RN100 | Nas listas e cobranças, o app exibe o apelido e, se não houver, o nome. | RF08 |
| RN101 | O telefone é oculto por padrão. Se o usuário o tornar visível, quem compartilha contexto com ele (RN107) passa a vê-lo. | RF10, RF101 |
| RN102 | A chave Pix é visível ao próprio usuário. A chave do recebedor de um jogo não cancelado é visível, desde a criação do jogo, a todos os participantes da lista, inclusive depois de pagarem. Também é visível a quem tem um valor Pendente ou Em análise devido a ele, como quem cancelou com multa. A prévia do convite não mostra a chave. | RF11, RF45, RF77 |
| RN103 | **A exclusão de conta é bloqueada se o usuário:** | RF13 |
|       | - tiver valor a pagar ou a receber Pendente ou Em análise; | |
|       | - for o último admin de um grupo (se for o único membro, pode excluir o grupo antes, RN17); | |
|       | - for o único admin ou o recebedor de um jogo Aberto ou Confirmado. | |
|       | **Risco aceito (09/11/2026):** o único admin de um jogo Concluído pode excluir a conta mesmo com valores Pendentes no jogo. Depois disso, a linha de admin continua (RN25), mas aponta para o perfil anônimo, e ninguém mais isenta multas nem troca o recebedor desse jogo. O recebedor continua podendo marcar como pago (RN84). | |
| RN104 | **Efeitos da exclusão:** o usuário sai das listas de presença e de espera de jogos não iniciados (sem multa) e dos grupos, suas solicitações pendentes são canceladas e seus dados pessoais são anonimizados, como descrito no `stacks.md` (13.2). | RF13 |
| RN105 | **Chave Pix:** pode ser trocada a qualquer momento, mas **não pode ser removida** enquanto o usuário for recebedor de um jogo Aberto ou Confirmado ou tiver valor a receber Pendente ou Em análise. O pagador sempre vê a chave atual (RF77). | RF11, RF12 |
| RN106 | **Fotos de perfil e de grupo:** JPEG, PNG ou WebP. O app redimensiona para no máximo 1024 px no maior lado antes do envio, e o servidor aceita até **2 MB**. | RF09, RF14, RF18 |
| RN107 | **Visibilidade do perfil:** nome, apelido e foto de um usuário são visíveis a quem compartilha contexto com ele, ou seja, um grupo atual ou qualquer jogo, atual ou passado, na lista de presença ou de espera. A mesma definição vale para o telefone visível (RN101). **Exceção:** quem tem o convite de um jogo e está logado vê, na prévia, o apelido ou nome e a foto dos participantes, mesmo sem contexto compartilhado. | RF19, RF46, RF48, RF101 |
 
## 11. Notificações
 
| ID | Regra | RF |
|----|-------|----|
| RN110 | Toda notificação é gravada no histórico antes do push e respeita as preferências do usuário. | RF88, RF98, RF99 |
| RN111 | Lembretes agendados são idempotentes: no máximo um por jogo, tipo, usuário e **horário de referência** (prazo, início ou fim). Se o admin alterar esse horário, um novo lembrete é enviado com base no novo horário. | RF92, RF93, RF94 |
| RN112 | Os lembretes de prazo e de início vão apenas a participantes da lista, não à lista de espera. | RF92, RF93 |
| RN113 | A cobrança às 9h e às 20h (RN01) é **uma notificação por usuário**, com o total dos valores Pendentes e o número de jogos, e abre a tela de valores a pagar (RF75). Valores Em análise, Pagos e Isentos não entram; sem valor Pendente, não há envio. | RF96 |
| RN114 | O cancelamento do jogo notifica a lista de presença e a lista de espera. | RF91 |
| RN115 | A troca de recebedor (antes ou após a conclusão) notifica o antigo e o novo recebedor e quem tem valor Pendente no jogo. | RF33, RF97 |
