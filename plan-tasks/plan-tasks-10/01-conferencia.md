# T10.1 — Conferência do estado do passo 3

**Estado:** feito · **Depende de:** —

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

- [x] Nenhuma caixa desmarcada nas tasks do passo 3, e o cabeçalho de cada uma batendo com a tabela do [README do passo 3](../passo-3/README.md). Varrer `- [x]` em `plan-tasks/passo-3/`, menos a T10.
- [x] `supabase start` e as três suítes SQL (`schema.sql`, `rls.sql`, `autenticacao.sql`). Anotar os totais e comparar com 61, 69 e 36.
- [x] `flutter test` e `dart analyze` a partir de `app/`. Anotar o total de testes e comparar com 41.
- [x] Decidir e registrar no Resultado se o `autenticacao_api.sh` roda de novo. **Proposta: não roda.** A rodada local fechou na T14, dois dias antes, sem mudança de código nem de migração depois dela; a remota gastaria cerca de 19 e-mails reais para repetir o que a T09.7 já tabelou. Se algo tiver mudado no código do app ou no `config.toml` desde a T14, a rodada local volta a ser obrigatória.
- [x] Pelo MCP do Supabase, **só leitura**: `auth.users`, `identities`, `sessions`, `pessoa` e `dispositivo_push` vazias no remoto, e as cinco migrações aplicadas. Confirma a frase do "Aberto" sobre o remoto chegar ao passo 4 sem usuário.
- [x] **[Thiago]** Confirmar na tela do painel que o teto de e-mails está em 30 por hora. O MCP não lê a configuração do Auth.
- [x] Ler o [`docs/prd.md`](../../docs/prd.md) (RF01, RF02, RF35, RF41, RN21, RNF06, RNF07) e a seção Autenticação de [`docs/stack.md`](../../docs/stack.md) e confirmar que nada do passo 3 ficou sem documento. Se achar divergência, **parar e perguntar**: é decisão de produto, não de registro.
- [x] Conferir que [`docs/design/telas/01-acesso/implementacao.md`](../../docs/design/telas/01-acesso/implementacao.md) cobre o que a entrada vai só apontar: as divergências das A1 a A4 (T05, T12), as duas mensagens de limite de envio (T14) e a troca de e-mail em "Fora das telas A" (T06).
- [x] Conferir as linhas de risco de `docs/stack.md` que a entrada repete em "Aberto": domínio até 26/10/2027, tela de consentimento em teste, chave de assinatura própria no passo 10, nome do cadastro de impostor, texto em inglês do teto.
- [x] Se algum número ou caixa divergir, corrigir **a task de origem**, não a entrada. A entrada da T10.2 lê o que estiver corrigido.

## Resultado

Feito em 2026-10-29. Nada divergiu, e o passo está pronto para fechar.

- **Caixas e cabeçalhos:** nenhum `- [x]` nas treze tasks (varredura em `plan-tasks/passo-3/`, fora a T10), e os catorze cabeçalhos batem com a tabela do README. Única correção: o espaço duplo no cabeçalho de [`11-google-cloud.md`](../passo-3/11-google-cloud.md).
- **Suítes SQL**, com o Supabase local já no ar: `schema.sql` **61**, `rls.sql` **69**, `autenticacao.sql` **36** asserções. São os três números esperados.
- **App:** `flutter test` com **41** testes, "All tests passed!", e `dart analyze` com "No issues found!". Também os esperados.
- **O `docker` roda sem `sg docker -c`** nesta sessão. É um item do "Aberto" do **passo 1** que caiu; não entra na entrada do passo 3, mas fica anotado para a T10.3 decidir se risca lá.
- **`autenticacao_api.sh` não roda de novo**, como a proposta. `git log a504c6f..HEAD -- app supabase` é vazio: o `HEAD` **é** o commit da T14, e nada de código, migração ou `config.toml` mudou depois dela. A rodada local da T14 (`SUCESSO: 18 cenários`) continua descrevendo este código, e a remota repetiria a tabela da T09.7 por cerca de 19 e-mails reais.
- **APK não rebuildado, e não precisou.** O `app/build/app/outputs/flutter-apk/app-release.apk` de 28/10 às 22:03 está no disco com **53.999.223 bytes**, o número da T09.3 e da T14, e o `libapp.so` dele traz as duas mensagens do teto. O commit a504c6f é de 22:34, meia hora depois do build, mas o build saiu do mesmo código: o `libapp.so` tem "Muitos códigos enviados agora…", "Aguarde um minuto…" e o padrão `after \d+ second`, os três iguais ao `auth_repositorio.dart` de hoje.
  - **Para quem repetir a conferência:** `grep` pelo texto com acento dentro do `.so` não acha nada. O Dart guarda string que cabe em Latin-1 como um byte por caractere, então o "ó" está como `0xF3` e não como os dois bytes do UTF-8. Procurar com `strings`, ou por um trecho só de ASCII.
- **Remoto, pelo MCP, só leitura:** as cinco migrações aplicadas (`enums`, `tabelas`, `indices`, `rls`, `autenticacao`), e `auth.users`, `auth.identities`, `auth.sessions`, `auth.refresh_tokens`, `auth.one_time_tokens`, `pessoa` e `dispositivo_push` todas em zero. Também em zero `local`, `quadra`, `horario_funcionamento`, `grupo`, `jogo` e `cobranca`: confirma de uma vez os dois itens do "Aberto", o remoto sem usuário e o `seed.sql` que não foi.
- **Teto de e-mails em 30 por hora**, confirmado pelo Thiago na tela do painel. O MCP não lê essa configuração.
- **Documentos sem lacuna.** A seção Autenticação de `docs/stack.md` cobre os dois gatilhos, o Google, os dois limites com os textos em inglês, o `secure_password_change` e a revogação dos aparelhos. No PRD, a RN21 já traz o cadastro refeito e a redefinição que conclui cadastro pendente, a RNF06 o limite de envios por hora e a RNF07 as sessões. **Nenhuma decisão de produto aberta.**
- **`implementacao.md` de `01-acesso`** cobre o que a entrada vai só apontar: a A3 do cadastro refeito (T13), a A4 em cinco pontos (T12), as duas mensagens de limite em "Todas" (T14) e a troca de e-mail em "Fora das telas A" (T06). As divergências da A1 estão em "Todas" (título em Montserrat 800 36 e o rodapé), sem seção própria.
- **Riscos de `docs/stack.md`:** as cinco linhas que o "Aberto" repete estão lá — domínio até 26/10/2027, consentimento em teste, chave de assinatura própria no passo 10, nome do cadastro de impostor e o texto em inglês do teto.

## Pronto quando

As três suítes SQL, o `flutter test` e o `dart analyze` passam, com os totais anotados; o remoto está vazio e com o teto em 30; nenhuma task do passo tem caixa desmarcada; e não há decisão de produto aberta.

## Commit

`Confere o estado do passo 3 antes do fechamento` — leva o Resultado desta task e qualquer correção que a conferência tenha feito nas tasks do passo. Se nada divergir e nada mudar além deste arquivo, o commit leva só ele.
