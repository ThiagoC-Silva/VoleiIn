# VoleiIn

App Android para grupos de vôlei de Parnaíba (PI). Organiza jogos e listas de presença, calcula o rateio e as multas ao concluir o jogo e acompanha os pagamentos por Pix entre os participantes, com leitura automática de comprovantes. O app não processa pagamentos.

**Estado atual:** fatia 1 concluída e na `main` (12/11/2026). **Fatia 2 (Conta e perfil) com o código pronto** no *branch* `fatia-2/conta-e-perfil` (13/11/2026): migrações, RLS, seed, telas e testes, com `dart analyze`, `flutter test`, `supabase test db` e `deno test` verdes. L06 a L11 verdes no emulador, nas APIs 29 e 36, acessibilidade (T049) e matriz de rastreabilidade feitas (13/11/2026). PR #3 com o CI verde. Falta: o *merge* e as migrações na produção (`setup.md`, 9.2), que o agente pode fazer; e, com o responsável, conferir cada tela contra o PNG (T051) e os testes com contas reais, M01 a M04 (Google e Resend). Depois, marcar a T053 e os RFs como concluídos.

## Antes de implementar

1. Veja em `docs/plano-implementacao.md` a fatia atual, seu escopo e o que fica fora dela.
2. Confira a lista de início de fatia na seção 8.4 de `plan-docs.md`.
3. Consulte os documentos abaixo. Não assuma regra, valor padrão ou nome que eles já definem.

| Documento | Use para |
|-----------|----------|
| `docs/requisitos.md` | O que o app faz (RF) |
| `docs/regras-negocio.md` | Como as regras funcionam (RN) e o glossário do domínio |
| `docs/modelo-dados.md` | Tabelas, enums, constraints e passo a passo de `complete_game` |
| `docs/contratos-api.md` | Assinatura, permissões, erros e efeitos de cada função |
| `docs/testes-referencia.md` | Resultados esperados dos cenários de maior risco |
| `docs/requisitos-nao-funcionais.md` | Android, velocidade, acessibilidade, custo e uso sem internet |
| `docs/stacks.md` | Tecnologias, bibliotecas, ambientes e CI |
| `docs/setup.md` | Ambientes, variáveis, segredos, seeds e produção |
| `docs/arquitetura-app.md` | Padrões do app (pastas, Riverpod, erros, Realtime, testes) e convenções do servidor |
| `docs/trabalho-com-agente.md` | Ciclo da fatia, definição de pronto, Git e PR, o que o agente nunca faz |
| `docs/ui/design-system.md` | Cores, fontes, componentes, mapa de status e tema Flutter |
| `docs/ui/telas.md` | Mapa de todas as telas e rotas, navegação e o detalhe das telas de cada fatia |
| `docs/copy.md` | Textos da interface (chaves do ARB), tom de voz, formatos e mensagens de erro |
| `docs/rls-matriz.md` | Privilégios e políticas de RLS por tabela, e a fatia que libera cada uma |
| `docs/rastreabilidade.md` | Cada RF com as RNs, a fatia, o banco, as telas, os testes e o status |
| `docs/adr/` | Decisões de arquitetura já tomadas, que não devem ser reabertas |
| `plan-docs.md` | Documentos ainda a escrever e o que cada fatia exige antes do código |

Em caso de conflito, siga `contratos-api.md` para assinaturas, `regras-negocio.md` para regras e `plano-implementacao.md` para escopo. **Se os documentos divergirem ou a regra for ambígua, pare e pergunte.** O documento prevalece sobre o código até ser atualizado.

Com o Spec Kit, cada `spec.md` cita os RFs e RNs em vez de copiar o texto: `docs/` é a fonte da verdade.

## Stack

Flutter (Android), Riverpod, `go_router` e `freezed`. Supabase (Postgres, Auth, Storage, Edge Functions em Deno, Realtime), `pg_cron`, FCM, Claude API e Resend. Testes com `flutter_test`, pgTAP e Deno test.

## Comandos

```bash
# em app/
dart analyze                    # análise estática (nunca flutter analyze: o "Á" do caminho o quebra, ADR 0014)
flutter test                    # testes unitários e de widget
flutter run --dart-define-from-file=env/local.json   # app no emulador, com o Supabase local

# na raiz
supabase start                  # sobe o Supabase local
supabase db reset               # recria o banco com migrações e seeds
supabase test db                # testes pgTAP
supabase migration new <nome>   # cria uma migração
supabase functions serve        # Edge Functions locais
deno test                       # testes das Edge Functions e de concorrência
scripts/emulator.sh 36          # abre o emulador (29 ou 36) com memória limitada
scripts/integration-test.sh     # testes de integração no emulador aberto
```

Primeira execução, variáveis e problemas comuns: `docs/setup.md`. Há dois ambientes: o **Supabase local** (desenvolvimento e homologação, com o app no emulador) e a **produção** (um projeto remoto só, ADR 0011).

## Convenções

- **Idiomas:** código, banco e nomes de arquivo em inglês. Interface e documentos em pt-BR.
- **App:** organização *feature-first* (`stacks.md`, seção 3.2), com `data`, `domain` e `presentation`.
- **Banco:** `snake_case`. Todo o schema muda por migração versionada.
- **Dinheiro:** `integer` em centavos, colunas `_cents`. Cálculos intermediários que possam estourar usam `bigint`.
- **Tempo:** `timestamptz` em UTC, exibido em `America/Fortaleza`.
- **Erros:** funções devolvem os códigos estáveis de `contratos-api.md`. O app converte o código em texto.
- **Textos:** nenhuma string de interface solta no código.
- **Memória:** emulador e testes de integração só pelos scripts de `scripts/`. Com o emulador aberto, um comando pesado por vez: nada de `flutter test`, `supabase test db`, `deno test` ou build em paralelo ao teste de integração. A soma já derrubou a sessão gráfica por falta de memória (`setup.md`, seção 3.1).

## Glossário

| pt-BR | Código |
|-------|--------|
| Recebedor | `receiver` |
| Valor a pagar | `charge` |
| Multa | `penalty` (`absence_penalty`, `late_cancellation_penalty`) |
| Rateio, parte por vaga | `split`, `share`, `share_cents` |
| Lista de presença | `game_participants` |
| Lista de espera | `game_waitlist` |
| Vaga, limite de vagas | `slot`, `slot_limit` |
| Prazo de cancelamento | `cancellation_deadline` |
| Comprovante | `receipt` |
| Convite | `invite_code` |
| Aberto, Confirmado, Cancelado, Concluído | `open`, `confirmed`, `cancelled`, `completed` |
| Pendente, Em análise, Pago, Isento | `pending`, `under_review`, `paid`, `waived` |
| Compartilhar contexto | `shares_context` |

## Nunca faça

- **Escrever direto em tabelas de regra.** Use as funções do servidor: só elas validam papel, tempo e estado. O que o app pode escrever direto está em `contratos-api.md`, seção 9.
- **Usar ponto flutuante para dinheiro.** Um centavo errado quebra o valor exato exigido na validação do comprovante (RN04, RN88).
- **Calcular rateio, multa ou status só no app.** O servidor decide, e o app apenas exibe.
- **Confiar no relógio do aparelho.** Prazos e início usam o relógio do servidor (RN02).
- **Colocar segredo no app ou no repositório.** No app, só identificadores públicos: a URL e a chave pública do Supabase, o ID do cliente web do Google e a configuração do Firebase. O resto fica nos *secrets* do GitHub e do Supabase (`setup.md`, seção 5).
- **Criar tabela sem RLS ou alterar política sem teste.** O RLS é o que protege telefone, chave Pix e comprovantes.
- **Aplicar migração na produção sem o ensaio.** O agente pode mexer na produção (decisão de 13/11/2026), mas o projeto não tem backup do banco (`requisitos-nao-funcionais.md`, seção 8): antes de cada `supabase db push`, o agente roda o ensaio de `setup.md`, seção 9.2.
- **Mudar um resultado esperado de `testes-referencia.md` para o teste passar.** Ele vem da regra. Se a regra parecer errada, pare e pergunte.
- **Implementar algo fora do escopo da fatia atual.**

## Definição de pronto

- Os testes da fatia foram escritos antes do código, falharam e agora passam.
- `dart analyze`, `flutter test`, `supabase test db` e `deno test` estão verdes.
- O fluxo de "Pronto quando" da fatia funciona de ponta a ponta.
- Nenhuma tabela está sem RLS.
- Todo bug corrigido ganhou um teste que o reproduz.
- Os documentos afetados foram atualizados.

O detalhe, com o checklist do PR, está em `docs/trabalho-com-agente.md` (seção 5).
