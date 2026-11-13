# 0018. A senha do cadastro é gravada de novo depois do código

- **Status:** Aceito
- **Data:** 2026-11-13

## Contexto
Quando alguém repete o cadastro de um e-mail que ainda não foi confirmado, o Supabase Auth reenvia o código, mas **mantém a senha do primeiro pedido**. Conferido no Supabase local em 13/11/2026 (research R5 de `specs/001-conta-e-perfil`): dois cadastros seguidos com `primeira-123` e `segunda-456` devolvem o mesmo usuário, e, depois do código, o login aceita só `primeira-123`.

Isso abre um caminho para tomar a conta de outra pessoa: quem cadastrar antes o e-mail dela, com uma senha que só ele conhece, fica com acesso à conta que ela confirmar. O dono do e-mail digita o código achando que criou a própria senha, e a senha que vale é a do outro. O v0 já tratava esse caso.

## Decisão
Depois do `verifyOTP` do cadastro, que cria a sessão, o app grava de novo a senha digitada na tela (`updateUser`). O erro `same_password`, que aparece quando a senha já era a mesma, é ignorado: é o caso comum, de quem cadastrou uma vez só.

## Alternativas descartadas
- **Não tratar:** deixa a tomada de conta descrita acima.
- **Pedir uma senha nova depois do código:** resolve, mas acrescenta um passo para todo mundo por causa de um caso raro.
- **Apagar o cadastro pendente no segundo pedido:** exige uma Edge Function com `service_role` só para isso, e o Supabase Auth não oferece a opção.

## Consequências
- O `docs/ui/telas.md` (5.3) inclui o passo depois do código. O `AuthRepository.confirmSignup` faz as duas chamadas (E12).
- O app guarda a senha em memória até o código, junto com o e-mail que o ADR 0017 já exigia (`accessDraftProvider`). Ela nunca vai para o aparelho nem para a rota.
- Se a regravação falhar depois de o código valer, a pessoa já está logada com a senha do primeiro pedido: o app mostra o erro, e ela pode trocar a senha no perfil (5.11).
- Vale vigiar o comportamento do Supabase Auth a cada atualização do CLI e da produção: se ele passar a trocar a senha no segundo cadastro, o passo fica inofensivo, mas desnecessário.
