# Tasks: Conclusão, multas e rateio, etapa C (fatia 5)

**Input**: `specs/008-conclusao-etapa-c/`. **Tests**: antes do código, com os resultados de `docs/testes-referencia.md`, seções 7 e 13, linha C.

## Sessão 2 — Servidor

- [x] T001 [P] B06 com `change_receiver(uuid,uuid)`
- [x] T002 [P] [US1] [US2] Z10 a Z15 em `completion_functions.test.sql`
- [x] T003 [P] [US1] [US2] V01 a V11 em `completion_split.test.sql`, com as notas de "Em todos" da seção 7
- [x] T004 [P] [US2] Y04 em `completion_security.test.sql`
- [x] T005 Saída da falha e *commit* só de testes
- [x] T006 Migração `create_change_receiver` (research R1 a R5)
- [x] T007 Seed com o jogo "Quinta com troca" (R7)
- [x] T008 Comandos verdes, documentos e PR

**Sessão 2 concluída em 19/11/2026** no *branch* `fatia-5/servidor-c`: `supabase test db` (779 testes), `supabase db lint`, `deno fmt --check`, `deno lint` e `deno test` (15 testes) verdes. Testes antes no *commit* `24c31d0`, com a saída da falha; o Y04 já passava, porque o recorte vem das políticas da etapa A (FR-003). Depois dele, só ajustes de estrutura, sem resultado esperado alterado: nomes de coluna no `set_eq` do Z15d (o pgTAP recusa coluna sem nome repetida) e `delete from public.receiver_changes` na limpeza do seed de sete arquivos das fatias 2 a 4, porque o seed passou a ter uma troca de recebedor.

- **Seed:** a research R7 dizia que o seed não mudava, mas a tabela de dados do `setup.md` (seção 8) pede uma troca de recebedor na etapa C. Ganhou o jogo "Quinta com troca" (`...0211`), no local "Quadra da Lagoa", para não repetir a "Arena Delta" que o L19 procura pelo texto.
- **Y04:** o Isento da Carla continua devido à Ana, e ela o vê (research R8). A linha foi acrescentada ao Y04 do `testes-referencia.md`.
- **`setup.md`:** a dica do `deno test` passou a citar o `SUPABASE_JWT_SECRET`, que os testes de concorrência pedem.

## Sessão 3 — App

- [ ] T009 Testes antes: S72 a S76, E15, L22
- [ ] T010 Troca de recebedor e aba Cobranças (`docs/ui/telas.md`, seção 8)
- [ ] T011 `dart format`, `dart analyze` e `flutter test` verdes

## Sessão 4 — Validação

- [ ] T012 L22 nas APIs 29 e 36
- [ ] T013 Ensaio e `supabase db push`; advisors
