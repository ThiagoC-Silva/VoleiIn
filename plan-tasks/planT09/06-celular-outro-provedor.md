# T09.6 — Celular: cadastro refeito e troca de e-mail

**Estado:** a fazer · **Depende de:** T09.5

## Objetivo

Com o endereço do **outro provedor**, a entrega fora do Gmail e dois caminhos que só foram conferidos no local: o cadastro refeito antes do código (cenário 6, corrigido na T13) e a troca de e-mail (13 e 16).

## O que já existe

- `autenticacao_api.sh --impostor <endereço>` cria o cadastro pendente com senha e nome "Impostor" e imprime o id. Sem `PSQL`, pula a conferência de banco; sem `MAILPIT_URL`, não pergunta nada, porque não lê o código.
- O Gmail 2 tem conta desde a T09.5, pelo Google: é o alvo do 16.

## O que falta

- [ ] **6 refeito.** `CHAVE=<chave pública> AUTH_URL=https://zmokpmovphikmobynssy.supabase.co/auth/v1 MAILPIT_URL= PSQL= supabase/testes/autenticacao_api.sh --impostor <outro provedor>`. O código do impostor chega à caixa do Thiago, que não o usa.
- [ ] **[Thiago]** Mais de 60 s depois, A2 com o mesmo endereço, outro nome e a senha descartável. Chega o código novo; A3; o início abre com "Olá, <nome da A2>", e chega "A senha da sua conta no VoleiIn foi trocada". Conferir por `curl`: a senha do impostor dá `invalid_credentials`, e a descartável entra. Pelo MCP: `pessoa.nome` é o da A2.
- [ ] **13.** **[Thiago]** Na sessão, trocar o e-mail para o Gmail 2 com `+t09`. O código chega só no endereço novo; o aviso "O e-mail da sua conta no VoleiIn foi trocado" chega no outro provedor; o snackbar "E-mail trocado. Os outros aparelhos foram desconectados."; o app segue logado com o e-mail novo.
- [ ] **16.** **[Thiago]** Trocar de novo, agora para o Gmail 2 sem sufixo: "Esse e-mail já pertence a outra conta.", a tela fica na etapa do e-mail, e nenhum e-mail chega.
- [ ] Anotar a hora do último e-mail desta task: a T09.7 só começa uma hora depois.

## Resultado

## Pronto quando

Depois do cadastro refeito valem o nome e a senha da A2, a troca de e-mail chega aos dois endereços certos, e o e-mail do outro provedor tem tempo, pasta e remetente anotados.

## Commit

`Registra o cadastro refeito e a troca de e-mail no remoto`
