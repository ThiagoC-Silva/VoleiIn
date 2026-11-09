# Documento de Requisitos
 
## 1. Autenticação e Conta
 
| RFXX | Descrição | Dependência |
|------|-----------|-------------|
| RF01 | O usuário deve poder criar uma conta com e-mail e senha, informando obrigatoriamente o nome. O nome só é gravado depois que o e-mail é confirmado (RF02). | - |
| RF02 | O app deve exigir a confirmação do e-mail por um código de 6 dígitos, enviado ao endereço e digitado no app, antes de liberar o acesso de contas criadas com e-mail e senha. | RF01 |
| RF03 | O usuário deve poder criar uma conta ou entrar com a conta Google, tendo o nome preenchido a partir dela. | - |
| RF04 | O usuário deve poder entrar no app com e-mail e senha. | RF01, RF02 |
| RF05 | O app deve manter a sessão do usuário ativa, sem exigir login a cada abertura. | RF03, RF04 |
| RF06 | O usuário deve poder recuperar a senha por um código de 6 dígitos enviado ao e-mail. | RF01 |
| RF07 | O usuário deve poder sair da conta (logout). | RF03, RF04 |
| RF08 | O usuário deve poder definir um apelido opcional. Nas listas e cobranças, o app exibe o apelido e, se não houver, o nome. | RF01, RF03 |
| RF09 | O usuário deve poder adicionar e alterar a foto de perfil, no formato e tamanho da RN106. | RF01, RF03 |
| RF10 | O usuário deve poder cadastrar seu número de telefone, de preenchimento opcional, e escolher se ele fica visível para outros usuários. Por padrão, o telefone fica oculto. | RF01, RF03 |
| RF11 | O usuário deve poder cadastrar sua chave Pix (tipo e valor), de preenchimento opcional. | RF01, RF03 |
| RF12 | O usuário deve poder editar seus dados de perfil (nome, apelido, foto, telefone, visibilidade do telefone e chave Pix). A remoção da chave Pix segue a RN105. | RF08, RF09, RF10, RF11 |
| RF13 | O usuário deve poder excluir sua conta, desde que não tenha valores a pagar nem a receber Pendentes ou Em análise, não seja o último admin de um grupo e não seja o único admin nem o recebedor de um jogo Aberto ou Confirmado (RN103). Os dados pessoais são anonimizados e o histórico de jogos e valores é mantido. | RF01, RF03, RF24, RF31, RF35 |
| RF101 | Quando o usuário tornar o telefone visível, o app deve exibi-lo no perfil para os usuários que compartilham contexto com ele (RN107). Quando o telefone estiver oculto, apenas o próprio usuário o vê. | RF10, RF19, RF46 |
| RF105 | O usuário deve aceitar os Termos de Uso e a Política de Privacidade ao criar a conta, inclusive pelo Google. O app registra a versão, a data e a hora do aceite e pede um novo aceite quando a versão de algum dos documentos mudar. | RF01, RF03 |
| RF106 | O usuário deve poder alterar o e-mail de acesso, com confirmação por um código de 6 dígitos enviado ao novo endereço. Até a confirmação, o e-mail anterior continua valendo. | RF01, RF02 |
| RF107 | O usuário com acesso por e-mail e senha deve poder alterar a senha estando logado, informando a senha atual. | RF01, RF04 |
| RF108 | Se o usuário entrar com uma conta Google cujo e-mail verificado já pertence a uma conta existente, o app deve vincular as duas formas de acesso à mesma conta, sem criar uma nova. | RF01, RF03 |
 
## 2. Grupos e Membros
 
| RFXX | Descrição | Dependência |
|------|-----------|-------------|
| RF14 | O usuário autenticado deve poder criar um grupo informando nome e, opcionalmente, foto (RN106). O criador torna-se admin do grupo. | RF03, RF04 |
| RF15 | O admin deve poder gerar um link ou código de convite para o grupo. | RF14 |
| RF16 | O usuário deve poder solicitar a entrada em um grupo por link ou código. A solicitação fica pendente até a decisão de um admin. | RF15 |
| RF17 | O admin deve poder ver as solicitações pendentes e aprová-las ou recusá-las. | RF16 |
| RF18 | O admin deve poder editar o nome e a foto do grupo. | RF14 |
| RF19 | O membro deve poder ver a lista de integrantes do grupo, com apelido (ou nome) e foto. | RF17 |
| RF20 | O admin deve poder remover um membro do grupo. | RF19 |
| RF21 | O membro deve poder sair do grupo. | RF17 |
| RF22 | O membro que sai ou é removido do grupo deve ser retirado das listas de todos os jogos do grupo ainda não iniciados, inclusive daqueles em que entrou pelo link, liberando as vagas, sem gerar multa. Ele também deixa de ser admin dos jogos do grupo Aberto ou Confirmado. Os jogos já iniciados ou concluídos e os valores em aberto são mantidos (RN14). | RF20, RF21, RF46 |
| RF23 | O admin deve poder promover um membro a admin e rebaixar outro admin a membro. O grupo pode ter mais de um admin. | RF19 |
| RF24 | O grupo deve sempre ter ao menos um admin. O último admin só pode sair ou ser rebaixado após promover outro. | RF23 |
| RF25 | O usuário deve poder participar de vários grupos e ver a lista dos seus grupos. | RF14, RF17 |
| RF102 | O app deve bloquear a saída (RF21) e a remoção (RF20) de um membro do grupo enquanto ele for o recebedor ou o único admin de um jogo do grupo Aberto ou Confirmado. Antes, é preciso indicar outro recebedor ou outro admin do jogo (RN16). | RF20, RF21, RF31, RF35 |
| RF103 | O admin deve poder excluir o grupo quando não houver jogo do grupo Aberto ou Confirmado. O grupo é arquivado: membros e solicitações pendentes são removidos, o convite é invalidado e os jogos concluídos e cancelados, com seus valores, continuam no histórico de quem participou (RN17). | RF14, RF24 |
 
## 3. Jogos
 
| RFXX | Descrição | Dependência |
|------|-----------|-------------|
| RF26 | Qualquer membro do grupo deve poder criar um jogo no grupo, informando data, horário de início e fim, local, valor total, limite de vagas e prazo de cancelamento. O criador torna-se admin do jogo. | RF19 |
| RF27 | O usuário autenticado deve poder criar um jogo avulso, fora de qualquer grupo, com os mesmos dados. O criador torna-se admin do jogo. | RF03, RF04 |
| RF28 | O local do jogo deve ser informado pelo nome, de preenchimento obrigatório, e, opcionalmente, pelo link do Google Maps. | RF26, RF27 |
| RF29 | O admin do jogo deve informar manualmente o valor total do espaço. O app deve exibir uma estimativa do valor por pessoa, calculada pelo valor total dividido pelo limite de vagas. | RF26, RF27 |
| RF30 | O admin do jogo deve definir o prazo de cancelamento como uma data e hora específicas. | RF26, RF27 |
| RF31 | Todo jogo deve ter um recebedor, ou seja, quem pagou o espaço e receberá os valores. O recebedor precisa estar na lista de presença do jogo. Por padrão é o criador, que entra na lista ao criar o jogo (RN21, RN28). | RF26, RF27, RF46 |
| RF32 | Para ser recebedor, o usuário deve estar na lista de presença e ter uma chave Pix cadastrada. Se não tiver a chave, o app deve pedir o cadastro antes de confirmar (RN28). | RF11, RF31, RF46 |
| RF33 | O admin do jogo deve poder alterar o recebedor a qualquer momento, inclusive após a conclusão do jogo. A troca após a conclusão segue as regras da RN31: fica bloqueada enquanto houver valor Em análise, os valores Pagos continuam vinculados ao antigo recebedor e os Pendentes passam a ser devidos ao novo. | RF32 |
| RF34 | O admin do jogo deve poder adicionar e remover outros admins do jogo. | RF26, RF27 |
| RF35 | O jogo deve sempre ter ao menos um admin. O admin que for o único do jogo só pode deixar o papel de admin após indicar outro. Sair da lista de presença não afeta o papel de admin (RN26). | RF34, RF50 |
| RF36 | O admin do jogo deve poder editar os dados do jogo. | RF26, RF27 |
| RF37 | O jogo deve ter um status: Aberto, Confirmado, Cancelado ou Concluído. | RF26, RF27 |
| RF38 | O jogo deve passar automaticamente de Aberto para Confirmado quando a lista de presença atingir o limite de vagas, e voltar de Confirmado para Aberto sempre que uma vaga for liberada. | RF37, RF46 |
| RF39 | O admin do jogo deve poder cancelar o jogo a qualquer momento até a sua conclusão (RN43). | RF37 |
| RF40 | O admin do jogo deve poder concluir o jogo manualmente após sua realização, podendo editar o valor total do jogo. A conclusão libera o rateio e é definitiva (RN36). | RF36, RF37 |
| RF41 | Ao concluir manualmente um jogo com vagas não cobertas (RN48), o app deve exibir ao admin o valor que ficará por conta do recebedor antes de confirmar a conclusão. O limite de vagas não pode ser alterado na conclusão. | RF40, RF58 |
| RF42 | O jogo que não for concluído manualmente deve ser concluído automaticamente 1 hora após o horário de fim, mantendo o valor total informado e sem registrar novas faltas, preservando apenas as faltas já registradas pela saída após o início do jogo (RN49). | RF40, RF50 |
| RF43 | O participante de um jogo deve poder gerar e compartilhar um link de convite desse jogo. | RF26, RF27 |
| RF44 | O usuário deve poder ver, próximos e concluídos e com o status de cada um, os jogos dos grupos de que é membro e todos os jogos de que participa ou participou, inclusive os jogos de grupo em que entrou pelo link sem ser membro. | RF26, RF27, RF48 |
| RF45 | O usuário deve poder abrir os detalhes de um jogo (dados, lista, recebedor e status). O participante da lista também vê a chave Pix do recebedor, desde a criação do jogo (RN102). | RF44 |
 
## 4. Lista de Presença
 
| RFXX | Descrição | Dependência |
|------|-----------|-------------|
| RF46 | Todo jogo deve ter uma lista de presença, respeitando o limite de vagas, exibindo o apelido (ou nome) e a foto de cada participante. | RF26, RF27 |
| RF47 | O membro do grupo deve poder confirmar presença em um jogo do grupo, entrando na lista se houver vaga. | RF19, RF46 |
| RF48 | O usuário com conta deve poder entrar na lista de um jogo pelo link de convite, sem precisar ser membro do grupo. | RF43, RF46 |
| RF49 | Quando a lista estiver cheia, o usuário deve poder entrar na lista de espera e sair dela a qualquer momento. | RF46 |
| RF50 | O participante deve poder sair da lista de presença. Antes do início do jogo, a saída libera a vaga e é tratada como cancelamento. Entre o início e o fim, a saída é registrada como falta e não libera a vaga. Após o horário de fim, a saída não é permitida (RN57). | RF47, RF48 |
| RF51 | A vaga liberada fica aberta a qualquer usuário que tente entrar naquele momento, e o primeiro que confirmar fica com ela. | RF49, RF50 |
| RF52 | O admin do jogo deve poder aumentar o limite de vagas, e cada vaga nova fica com o primeiro que confirmar. | RF36, RF49 |
| RF53 | O app deve impedir a redução do limite de vagas para um número menor que o de participantes confirmados. | RF36, RF46 |
| RF54 | O admin do jogo deve poder remover um participante da lista de presença apenas até o início do jogo. Após o início, o admin usa a falta e a isenção manual (RN58). | RF46 |
| RF55 | O app deve permitir entrar na lista de presença e na lista de espera até o horário de início do jogo, e não deve permitir a entrada em jogos cancelados ou concluídos. | RF37, RF46 |
 
## 5. Cancelamentos, Faltas e Multas
 
| RFXX | Descrição | Dependência |
|------|-----------|-------------|
| RF56 | O cancelamento feito até a data e hora do prazo de cancelamento do jogo não gera multa, e o participante não paga nenhum valor. O app deve registrar a data e hora do cancelamento. | RF30, RF50 |
| RF57 | O cancelamento feito após o prazo de cancelamento e antes do início do jogo gera uma multa ao participante, sujeita à isenção do RF58. | RF30, RF50 |
| RF58 | A multa por cancelamento fora do prazo deve ser isentada automaticamente na conclusão do jogo, conforme o cálculo da RN62: considera-se o menor limite de vagas vigente entre o prazo de cancelamento e o início e o número de participantes no início para apurar as vagas ociosas. Mantêm-se as multas dos últimos a cancelar, e os primeiros a cancelar são isentados. | RF51, RF57 |
| RF59 | O participante removido da lista pelo admin do jogo não deve receber multa. | RF54 |
| RF60 | Ao concluir o jogo, o admin deve registrar quem faltou. Por padrão, todos da lista de presença contam como presentes. | RF40, RF46, RF50 |
| RF61 | O participante registrado como faltoso deve receber uma multa. | RF60 |
| RF62 | O valor da multa deve ser igual à parte de cada vaga, calculada conforme o RF67. | RF67 |
| RF63 | O recebedor do jogo não deve receber multa por cancelamento ou falta. | RF31, RF57, RF61 |
| RF64 | O admin do jogo deve poder isentar manualmente uma multa Pendente. O valor passa para Isento (RN66, RN93). | RF57, RF61 |
| RF65 | O participante deve poder ver seus cancelamentos, faltas e multas em cada jogo. | RF56, RF61 |
 
## 6. Rateio
 
| RFXX | Descrição | Dependência |
|------|-----------|-------------|
| RF66 | O jogo cancelado não deve gerar rateio. | RF39 |
| RF67 | Ao concluir o jogo, o app deve calcular a parte de cada vaga: valor total do jogo dividido pelo limite de vagas, arredondado para cima ao centavo. | RF29, RF40 |
| RF68 | Cada participante que jogou, inclusive quem entrou em uma vaga aberta, deve ter um valor a pagar igual à sua parte. | RF60, RF67 |
| RF69 | Cada participante com multa deve ter um valor a pagar igual à multa. | RF57, RF61, RF62 |
| RF70 | O participante cuja multa foi isentada automaticamente não deve ter valor a pagar. | RF58 |
| RF71 | Todos os valores a pagar de um jogo são devidos ao recebedor do jogo. O recebedor não deve ter valor a pagar para si mesmo. | RF31, RF68, RF69 |
| RF72 | Cada valor a pagar deve ter um status: Pendente, Em análise, Pago ou Isento. O valor Isento (multa isentada manualmente ou valor anulado na troca de recebedor) fica no histórico, mas não entra nos totais nem nas cobranças. | RF68, RF69 |
| RF73 | O participante deve poder ver o rateio do jogo concluído: valor total, parte por vaga, o que ele deve e o status. | RF68, RF72 |
| RF74 | O recebedor e os admins do jogo devem poder ver o rateio completo, com o valor e o status de cada participante e o total já recebido e pendente. | RF71, RF72 |
| RF75 | O usuário deve poder ver o total que deve, somando todos os jogos, com o detalhamento por jogo e por recebedor. | RF72, RF73 |
| RF76 | O recebedor deve poder ver o total que tem a receber, somando todos os jogos, com a lista de quem lhe deve e o valor de cada um. | RF72, RF74 |
 
## 7. Pagamentos e Comprovantes
 
| RFXX | Descrição | Dependência |
|------|-----------|-------------|
| RF77 | O participante com valor a pagar deve ver o valor, o nome do recebedor e a chave Pix atual dele, podendo copiar a chave. | RF11, RF71, RF72 |
| RF78 | O participante deve poder enviar o comprovante de pagamento (imagem ou PDF) referente ao seu valor a pagar. Enquanto a leitura de um comprovante estiver em curso, o app não permite novo envio para o mesmo valor. | RF72 |
| RF79 | O app deve ler automaticamente o comprovante, extraindo valor, data e hora, destinatário e ID da transação. | RF78 |
| RF80 | O app deve validar automaticamente o comprovante, conferindo se o valor, o destinatário e a data e hora correspondem ao valor a pagar e se o pagamento foi feito no minuto do início do jogo ou depois, inclusive antes da conclusão (RN88). | RF79 |
| RF81 | O app deve recusar o envio de um comprovante cujo ID de transação já esteja em um comprovante Aprovado ou Em análise de outro pagamento, informando o motivo ao pagador. Se aquele comprovante for recusado, o ID volta a ficar livre (RN89). | RF79 |
| RF82 | Se o comprovante for validado, o valor a pagar passa automaticamente para Pago. | RF80, RF81 |
| RF83 | Se o comprovante não puder ser lido, tiver valor diferente do exato ou não conferir com o destinatário, ele deve ir para análise manual do recebedor e o valor a pagar passa para Em análise. Se aprovado, o valor passa para Pago. Se recusado, o valor volta para Pendente, com uma observação do recebedor. | RF72, RF80 |
| RF84 | O recebedor deve poder marcar manualmente um valor a pagar como Pago, sem comprovante. | RF71, RF72 |
| RF85 | O recebedor deve poder reverter para Pendente um valor que ele marcou manualmente como Pago. O app registra quem fez a reversão e quando, e notifica o participante. Os valores aprovados por comprovante não podem ser revertidos. | RF84 |
| RF86 | O participante deve poder ver os comprovantes que enviou, com o status (Em análise, Aprovado ou Recusado) e a observação do recebedor, quando houver. Após a exclusão do arquivo (RF87), o participante continua vendo o status e a observação, mas não consegue abrir o arquivo. | RF78, RF83, RF87 |
| RF87 | Os comprovantes devem ser armazenados de forma privada, acessíveis apenas ao pagador e ao recebedor. O arquivo do comprovante deve ser apagado 30 dias após a decisão sobre ele (aprovação ou recusa). O registro do comprovante fica guardado por completo no histórico: dados lidos, resultado das conferências, status, observação do recebedor e ID da transação. O comprovante Em análise não é apagado (RN91, RN92). | RF78, RF83 |
 
## 8. Notificações e Compartilhamento
 
| RFXX | Descrição | Dependência |
|------|-----------|-------------|
| RF88 | O app deve enviar notificações push ao usuário. | RF05 |
| RF89 | O app deve notificar o solicitante quando sua entrada em um grupo for aprovada ou recusada, e os admins do grupo quando houver nova solicitação. | RF16, RF17 |
| RF90 | O app deve notificar os integrantes da lista de espera quando uma vaga for liberada ou o limite de vagas for aumentado. | RF51, RF52 |
| RF91 | O app deve notificar os participantes quando o jogo for confirmado, cancelado ou concluído, ou quando seus dados forem alterados. | RF36, RF37 |
| RF92 | O app deve enviar aos participantes um lembrete 2 horas antes do prazo de cancelamento do jogo. Se o prazo mudar, um novo lembrete é enviado (RN111). | RF30, RF46 |
| RF93 | O app deve enviar aos participantes um lembrete 2 horas antes do início do jogo. Se o início mudar, um novo lembrete é enviado (RN111). | RF46 |
| RF94 | O app deve notificar os admins do jogo no horário de fim, lembrando-os de concluí-lo. | RF40 |
| RF95 | O app deve notificar o participante quando houver um valor a pagar, incluindo as multas aplicadas. | RF68, RF69 |
| RF96 | O app deve enviar a cada usuário com valor Pendente uma notificação às 9h e outra às 20h, todos os dias, com o total pendente e o número de jogos, até não haver mais valor Pendente. Valores Em análise não entram no total (RN113). | RF72, RF75 |
| RF97 | O app deve notificar o recebedor quando um comprovante for enviado para análise manual, e o participante quando o valor for marcado como Pago ou voltar para Pendente. Na troca de recebedor, o app deve notificar o antigo e o novo recebedor e quem tem valor Pendente no jogo (RN115). | RF33, RF82, RF83, RF85 |
| RF98 | O usuário deve poder ativar ou desativar cada tipo de notificação. | RF88 |
| RF99 | O app deve ter um ícone de sino com o histórico das notificações recebidas pelo usuário. | RF88 |
| RF100 | O participante deve poder compartilhar a lista de presença em texto, no formato usado no WhatsApp: título com local e horário, lista numerada por ordem de entrada e a lista de espera incluída. | RF46, RF49 |
| RF104 | O app deve notificar: o participante removido da lista pelo admin do jogo; o membro removido do grupo ou cujo grupo foi excluído; o participante cuja multa foi isentada, automática ou manualmente; e o recebedor quando um valor passar para Pago por comprovante aprovado automaticamente. | RF20, RF54, RF58, RF64, RF82, RF103 |
