# Registro de Decisões de Arquitetura (ADRs)

Cada arquivo registra uma decisão que alguém poderia querer reabrir: o contexto, a decisão, as alternativas descartadas e as consequências. O objetivo é que o agente não refaça uma discussão já encerrada.

- Um ADR aceito só muda com um ADR novo que o substitua. O antigo passa a "Substituído por NNNN".
- A regra de negócio continua nos documentos de `docs/`. O ADR explica por que a arquitetura é como é.
- Formato: o modelo abaixo, em até uma página.

| Nº | Decisão | Status |
|----|---------|--------|
| [0001](0001-android-primeiro-com-flutter.md) | Android primeiro, com Flutter | Aceito |
| [0002](0002-supabase-em-sao-paulo.md) | Supabase como backend, em `sa-east-1` | Aceito |
| [0003](0003-dinheiro-em-centavos.md) | Dinheiro em centavos inteiros, com arredondamento para cima | Aceito |
| [0004](0004-regras-no-servidor.md) | Regras no servidor, nunca só no app | Aceito |
| [0005](0005-comprovantes-por-llm.md) | Leitura de comprovantes por LLM, com validação determinística | Aceito |
| [0006](0006-anonimizacao-e-arquivamento.md) | Anonimização de contas e arquivamento de grupos | Aceito |
| [0007](0007-fuso-unico.md) | Fuso único `America/Fortaleza` | Aceito |
| [0008](0008-app-links-no-cloudflare.md) | App Links próprios, com página no Cloudflare Pages | Aceito |
| [0009](0009-observabilidade-adiada.md) | Observabilidade dedicada adiada | Aceito |
| [0010](0010-spec-kit.md) | Spec Kit como único framework de especificação | Aceito |
| [0011](0011-um-projeto-supabase.md) | Um projeto Supabase remoto; homologação no local | Aceito |
| [0012](0012-um-app-sem-flavors.md) | Um app só, sem *flavors*; homologação no emulador | Aceito |
| [0013](0013-modo-escuro-e-visual-do-v0.md) | Só modo escuro, com o visual herdado do v0 | Aceito |
| [0014](0014-dart-analyze.md) | `dart analyze` no lugar de `flutter analyze` | Aceito |
| [0015](0015-esquema-private.md) | Funções auxiliares no esquema `private` e privilégios revogados | Aceito |
| [0016](0016-created-at-nas-tabelas-de-juncao.md) | `created_at` segue a lista de colunas de cada tabela | Aceito |
| [0017](0017-codigo-por-email.md) | Código de 6 dígitos por e-mail no lugar de link | Aceito |
| [0018](0018-senha-do-cadastro-pendente.md) | A senha do cadastro é gravada de novo depois do código | Proposto |

## Modelo

```markdown
# NNNN. Título

- **Status:** Aceito | Substituído por NNNN
- **Data:** aaaa-mm-dd

## Contexto
O problema e as restrições que levaram à decisão.

## Decisão
O que foi decidido, em uma ou poucas frases.

## Alternativas descartadas
- Alternativa: por que não.

## Consequências
O que fica mais fácil, o que fica mais difícil e o que precisa ser vigiado.
```
