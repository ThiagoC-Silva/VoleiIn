# Implementação — A · Acesso

Onde o app diverge das imagens A1 a A4, ou completa o que elas não mostram. O PRD vence o design em comportamento ([DESIGN.md](../../DESIGN.md), Precedência); aqui fica o registro de cada caso.

Telas: `app/lib/features/auth/` — `entrar_tela.dart` (A1), `criar_conta_tela.dart` (A2), `confirmar_email_tela.dart` (A3) e `redefinir_senha_tela.dart` (A4).

## A4 — Redefinir senha

- **A etapa do e-mail não foi desenhada.** A A4 é a segunda etapa: código e senha nova. A primeira pede o e-mail e envia o código ("Enviar código"), no estilo dos campos da A2, com o botão no pé como o "Salvar nova senha". Aberta pela A1 ("Esqueci a senha"), o campo vem com o e-mail já digitado; aberta pela sessão ("Trocar senha"), vem travado no e-mail da conta.
- **O texto muda sem sessão.** O serviço responde igual para e-mail sem conta e não envia nada (`docs/stack.md`, Autenticação), então a tela não pode afirmar que o código foi enviado. Sem sessão: "Se houver conta com **x**, enviamos um código. Digite-o e escolha a nova senha." Pela sessão, a conta existe e vale o texto do desenho: "Digite o código enviado para **x** e escolha a nova senha."
- **Reenvio do código.** A imagem não mostra, mas a RNF06 e a T12 pedem. Entra sob as casas, com a mesma pílula da A3.
- **"Salvar nova senha" desabilitado** até as seis casas e a senha de 8 caracteres, como o "Criar conta" da A2. A senha é conferida antes do código porque a conferência cria a sessão.

## Todas

- **Erro do serviço** (senha incorreta, código vencido, e-mail que já tem conta) não foi desenhado. Aparece acima do botão primário, com o ícone `error` e o texto na cor de erro. Erro de um campo (e-mail sem arroba, senha curta na A1) fica no próprio campo, com borda, ícone e mensagem, como manda o componente Campo.
- **Carregamento** não foi desenhado. O botão primário troca o texto por um indicador circular, e os campos e o voltar ficam travados durante a chamada.
- **Título da A1** em Montserrat 800 36, medido na imagem, e não no `title.xl` de 28, que é o da barra de tela-raiz.
- **Rodapé da A1** ("Ainda não tem conta? Criar conta") desce até o pé quando sobra espaço e segue o formulário quando não sobra, como com o teclado aberto. Quebra em duas linhas em vez de estourar com fonte grande.

## Fora das telas A

- **"Trocar senha" no início provisório** (`app/lib/features/feed/inicio_tela.dart`). O lugar dele é o perfil (H1), que ainda não existe; até lá, fica ao lado de "Trocar e-mail".
- **Troca de e-mail** (`app/lib/features/perfil/trocar_email_tela.dart`) já usa as seis casas e o reenvio da A3, mas o resto da H3 ainda não foi aplicado.
