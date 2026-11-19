# Tasks: Conclusão, multas e rateio, etapa C (fatia 5)

**Input**: `specs/008-conclusao-etapa-c/`. **Tests**: antes do código, com os resultados de `docs/testes-referencia.md`, seções 7 e 13, linha C.

## Sessão 2 — Servidor

- [ ] T001 [P] B06 com `change_receiver(uuid,uuid)`
- [ ] T002 [P] [US1] [US2] Z10 a Z15 em `completion_functions.test.sql`
- [ ] T003 [P] [US1] [US2] V01 a V11 em `completion_split.test.sql`, com as notas de "Em todos" da seção 7
- [ ] T004 [P] [US2] Y04 em `completion_security.test.sql`
- [ ] T005 Saída da falha e *commit* só de testes
- [ ] T006 Migração `create_change_receiver` (research R1 a R5)
- [ ] T007 Comandos verdes, documentos e PR

## Sessão 3 — App

- [ ] T008 Testes antes: S72 a S76, E15, L22
- [ ] T009 Troca de recebedor e aba Cobranças (`docs/ui/telas.md`, seção 8)
- [ ] T010 `dart format`, `dart analyze` e `flutter test` verdes

## Sessão 4 — Validação

- [ ] T011 L22 nas APIs 29 e 36
- [ ] T012 Ensaio e `supabase db push`; advisors
