# T10 — Fechamento do passo 3

**Estado:** a fazer · **Depende de:** T09

## Objetivo

Registrar o passo 3 em `docs/progresso.md` e liberar o passo 4.

## O que falta

- [ ] `docs/progresso.md`:
  - "Passo atual" → 4; na tabela, passo 3 → feito;
  - entrada "Passo 3 — Autenticação", pelo modelo do fim do arquivo.
- [ ] Decisões de implementação a registrar (o que não está no PRD):
  - `minSdk` 24, porque o Flutter atual já não dá suporte ao Android 6;
  - telas codadas sem especificação; o design será refeito depois;
  - a chave do Supabase entra no app por `--dart-define` (`SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`), nunca em arquivo versionado;
  - o reenvio de código conta 60 s no app só para evitar um toque que seria recusado; o limite é do servidor;
  - as escritas em `auth.users` nos testes SQL são feitas como `postgres`; o caminho real pelo Auth foi conferido na T07.
- [ ] "Aberto" a registrar:
  - especificação de telas e design ainda por fazer;
  - `flutter analyze` quebra com o caminho "Área de trabalho"; contorno pelo `dart analyze` (link simbólico não resolve);
  - resultado do cenário 11 da T07 (perfil criado por cadastro não confirmado), se aconteceu;
  - `inicio_tela.dart` é provisória; sair ainda não apaga o aparelho de push (passo 7).
- [ ] Atualizar o estado de todas as tasks em `plan-tasks/passo-3/README.md`.
- [ ] Atualizar a memória do projeto: passo 3 fechado e `plan-tasks/` versionado por passo.

## Pronto quando

- `docs/progresso.md` mostra o passo 3 como feito, com data.
- `git status` limpo.

## Commit

`Fecha o passo 3 — Autenticação`
