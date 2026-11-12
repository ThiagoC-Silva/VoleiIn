# Research: Conta e perfil (fatia 2)

Decisões técnicas que os documentos deixam para a implementação. Regra de produto não é decidida aqui.

## R1. `google_sign_in` 7.2: seletor fechado chega como exceção

- **Decision:** o pacote fica atrás de uma classe pequena, `GoogleIdTokenSource`, que devolve o ID token ou **nulo** quando a pessoa fecha o seletor. O repositório troca o token por sessão com `signInWithIdToken`.
- **Rationale:** na versão 7, `authenticate()` não devolve nulo: lança `GoogleSignInException` com o código `canceled`. A classe converte esse caso em nulo, que é o que `docs/copy.md` (6.8) e o cenário E12 descrevem. Qualquer outra exceção vira `authGoogleFailed`. A classe também torna o Google trocável por dublê nos testes.
- **Alternatives considered:** usar `GoogleSignIn.instance` direto no repositório (não dá para testar sem o plugin).
- **Lição do v0:** sem o SHA-1 da chave cadastrado, o Play Services também responde `canceled`. Nesse caso a tela fica muda. O `setup.md` (6.2) já descreve o sintoma no `logcat`.

## R2. Sessão criada no meio da recuperação de senha

- **Decision:** um provider em memória marca "recuperação em andamento". Enquanto ele está ligado, o roteador não tira a pessoa da `/forgot-password`, embora ela já tenha sessão.
- **Rationale:** o `verifyOTP` de recuperação cria a sessão antes do `updateUser` (`docs/ui/telas.md`, 5.4). Sem a marca, o redirecionamento "com sessão numa rota de acesso → `/games`" trocaria de tela antes de a senha ser gravada, e o caso do S08 (senha recusada depois do código) não teria tela.
- **Alternatives considered:** navegar à mão depois do `updateUser` (o roteador redirecionaria antes).

## R3. Conferência dos termos no roteador

- **Decision:** um `FutureProvider` por usuário logado calcula o que falta aceitar. Com sessão e sem o resultado "em dia" (carregando, erro ou faltando), o roteador manda para `/terms`, e é a própria tela que mostra carregando, erro com "Tentar de novo" ou o aceite. Quando o resultado fica em dia, o roteador segue para `/games`.
- **Rationale:** é o que `docs/ui/telas.md` (3.1) pede, com um lugar só para os três estados.
- **Alternatives considered:** uma rota de carregamento separada (uma tela a mais, sem ganho).

## R4. Riverpod 3 repete sozinho uma leitura que falhou

- **Decision:** a repetição automática fica desligada no `ProviderScope` do app e dos testes.
- **Rationale:** o Riverpod 3 tenta de novo, com espera crescente, todo provider que falha. O `design-system.md` (7.16) define o estado de erro com o botão "Tentar de novo": a repetição é da pessoa. Entra em `docs/arquitetura-app.md`, seção 5.

## R5. Senha do cadastro pendente (divergência a sinalizar)

- **Decision:** depois de confirmar o código do cadastro, o app grava de novo a senha digitada (`updateUser`), ignorando `same_password`.
- **Rationale:** quando alguém repete o cadastro de um e-mail ainda não confirmado, o Supabase Auth reenvia o código, mas **mantém a senha do primeiro pedido**. Quem cadastrasse antes o e-mail de outra pessoa ficaria sabendo a senha da conta que ela confirmar. O v0 já tratava assim. A conferência do comportamento no Supabase local é a primeira tarefa da fase de base (T009).
- **Documento:** `docs/ui/telas.md` (5.3) não cita esse passo. A correção entra no mesmo PR e é sinalizada ao responsável.

## R6. Dígitos de CPF e CNPJ na constraint

- **Decision:** `private.is_valid_cpf` e `private.is_valid_cnpj` recebem `execute` para `authenticated`, sem `usage` no esquema.
- **Rationale:** a constraint roda com os privilégios de quem faz o `update`. Sem o `execute`, a escrita do próprio app falharia. Sem `usage` no esquema `private`, a função continua inalcançável pela API. Entra na `docs/rls-matriz.md`, fatia 2.
- **Alternatives considered:** validar numa *trigger* `security definer` (o `modelo-dados.md` pede constraint).

## R7. Nome e tipo do arquivo da foto

- **Decision:** o tipo vem da extensão do arquivo devolvido pelo `image_picker` (`jpg`, `jpeg`, `png`, `webp`). O nome é um UUID v4 gerado no app com `Random.secure`.
- **Rationale:** evita dois pacotes (`mime` e `uuid`) para duas funções de poucas linhas (`docs/arquitetura-app.md`, seção 3: pacote novo precisa de motivo).

## R8. Máscaras dos campos

- **Decision:** `TextInputFormatter` próprios para CPF, CNPJ e telefone, em `core/format/input_masks.dart`.
- **Rationale:** sem pacote novo, e as mesmas funções de formatação servem para exibir (U04, U05).

## R9. Texto do `errorAuthEmailNotConfirmed` no ARB

- **Decision:** o ARB passa a ter o texto do `docs/copy.md` (5.5): "Confirme o seu e-mail antes de entrar."
- **Rationale:** o ARB da fatia 1 ainda fala em "link", que o ADR 0017 trocou por código. O documento prevalece.

## R10. Teste do Storage no CI

- **Decision:** o `avatars_test.ts` roda no job `database`, depois do `supabase db reset`, com a URL e a chave pública lidas de `supabase status`.
- **Rationale:** o job `functions` não sobe o Supabase (`docs/testes-referencia.md`, 10.3: "roda no job do CI que sobe o Supabase").

## R11. Google no Supabase local e no CI

- **Decision:** `[auth.external.google]` com o `client_id` do cliente web (identificador público, o mesmo do v0), `secret = "env(SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET)"` e `skip_nonce_check = true`. No CI, a variável recebe um valor qualquer.
- **Rationale:** o app não envia *nonce*, e o CLI exige a opção para o Google no local. O CI não faz login com Google, mas o `supabase start` precisa da variável.

## R12. "Confirme o seu e-mail" sem quebra no hífen

- **Decision:** o texto do ARB usa o hífen que não quebra (U+2011) nesse título, se a Montserrat tiver o glifo. Sem o glifo, usa o hífen comum entre dois U+2060.
- **Rationale:** `docs/ui/referencias/README.md`, conferência dos PNGs.
