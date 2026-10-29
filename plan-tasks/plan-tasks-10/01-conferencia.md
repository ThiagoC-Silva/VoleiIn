# T10.1 — Conferência do estado do passo 3

**Estado:** a fazer · **Depende de:** —

## Objetivo

Confirmar, antes de escrever uma linha de registro, que o passo 3 está de fato pronto para fechar: as suítes passam, os números que vão à entrada são os de hoje, nenhuma task deixou caixa desmarcada e nenhuma decisão de produto está aberta.

É a task que impede o passo de fechar em cima de um número decorado. Os totais das suítes e o tamanho do APK entram na entrada do `progresso.md`, então são medidos aqui, não copiados.

## O que já existe

- **Os comandos das suítes** em [`supabase/CLAUDE.md`](../../supabase/CLAUDE.md) e no [`CLAUDE.md`](../../CLAUDE.md) da raiz. Os totais esperados, pelas tasks anteriores: `schema.sql` 61 asserções, `rls.sql` 69, `autenticacao.sql` 36 (T14), `flutter test` 41 testes (T14), `dart analyze` sem nada.
- **`flutter analyze` não roda nesta máquina**, por causa do "Á" de "Área de trabalho"; o `dart analyze` é o caminho (`CLAUDE.md` da raiz).
- **O roteiro da API** (`autenticacao_api.sh`) fechou local com `SUCESSO: 18 cenários` na T14 e remoto na T09.7. Rodar de novo gasta e-mail no remoto e cinco minutos no local; a decisão de rodar ou não está em "O que falta".
- **O remoto** foi deixado limpo e com o teto em 30 na T14, conferido pelo MCP e pelo Thiago na tela do painel.
- **Os números do APK:** 53.999.223 bytes no release (T09.3, confirmado igual na T14) e 107,5 MB no de depuração; os acréscimos de biblioteca da T04 (+412 KB) e da T05 (+507 KB, de 53.144.602 para 53.664.236 bytes).

## O que falta

- [ ] Nenhuma caixa desmarcada nas tasks do passo 3, e o cabeçalho de cada uma batendo com a tabela do [README do passo 3](../passo-3/README.md). Varrer `- [ ]` em `plan-tasks/passo-3/`, menos a T10.
- [ ] `supabase start` e as três suítes SQL (`schema.sql`, `rls.sql`, `autenticacao.sql`). Anotar os totais e comparar com 61, 69 e 36.
- [ ] `flutter test` e `dart analyze` a partir de `app/`. Anotar o total de testes e comparar com 41.
- [ ] Decidir e registrar no Resultado se o `autenticacao_api.sh` roda de novo. **Proposta: não roda.** A rodada local fechou na T14, dois dias antes, sem mudança de código nem de migração depois dela; a remota gastaria cerca de 19 e-mails reais para repetir o que a T09.7 já tabelou. Se algo tiver mudado no código do app ou no `config.toml` desde a T14, a rodada local volta a ser obrigatória.
- [ ] Pelo MCP do Supabase, **só leitura**: `auth.users`, `identities`, `sessions`, `pessoa` e `dispositivo_push` vazias no remoto, e as cinco migrações aplicadas. Confirma a frase do "Aberto" sobre o remoto chegar ao passo 4 sem usuário.
- [ ] **[Thiago]** Confirmar na tela do painel que o teto de e-mails está em 30 por hora. O MCP não lê a configuração do Auth.
- [ ] Ler o [`docs/prd.md`](../../docs/prd.md) (RF01, RF02, RF35, RF41, RN21, RNF06, RNF07) e a seção Autenticação de [`docs/stack.md`](../../docs/stack.md) e confirmar que nada do passo 3 ficou sem documento. Se achar divergência, **parar e perguntar**: é decisão de produto, não de registro.
- [ ] Conferir que [`docs/design/telas/01-acesso/implementacao.md`](../../docs/design/telas/01-acesso/implementacao.md) cobre o que a entrada vai só apontar: as divergências das A1 a A4 (T05, T12), as duas mensagens de limite de envio (T14) e a troca de e-mail em "Fora das telas A" (T06).
- [ ] Conferir as linhas de risco de `docs/stack.md` que a entrada repete em "Aberto": domínio até 26/10/2027, tela de consentimento em teste, chave de assinatura própria no passo 10, nome do cadastro de impostor, texto em inglês do teto.
- [ ] Se algum número ou caixa divergir, corrigir **a task de origem**, não a entrada. A entrada da T10.2 lê o que estiver corrigido.

## Resultado

## Pronto quando

As três suítes SQL, o `flutter test` e o `dart analyze` passam, com os totais anotados; o remoto está vazio e com o teto em 30; nenhuma task do passo tem caixa desmarcada; e não há decisão de produto aberta.

## Commit

`Confere o estado do passo 3 antes do fechamento` — leva o Resultado desta task e qualquer correção que a conferência tenha feito nas tasks do passo. Se nada divergir e nada mudar além deste arquivo, o commit leva só ele.
