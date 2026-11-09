# 0013. Só modo escuro, com o visual herdado do v0

- **Status:** Aceito
- **Data:** 2026-11-09

## Contexto
O projeto anterior (VoleiIn v0) tinha um design fechado: cores, fontes, componentes e 38 telas em PNG, com base escura e opção de modo claro. O domínio mudou desde então (comprovante lido pela Claude API, sem Locais, status novos).

## Decisão
- Do v0 vêm só as **cores, fontes e componentes**, ajustados aos enums atuais e ao toque mínimo de 48 dp (`docs/ui/design-system.md`). Os PNGs não vêm: cada tela é descrita em `docs/ui/telas.md`, na fatia que a usa.
- O app tem **só o modo escuro**, sem opção de aparência.

## Alternativas descartadas
- **Trazer os PNGs:** mostram comportamentos que não existem mais e seriam uma segunda fonte de verdade.
- **Design novo:** refaria um trabalho visual já fechado e aprovado.
- **Escuro e claro:** dobraria a conferência de contraste e de cada tela.

## Consequências
- Uma base de cores só, e o tema não depende do modo do sistema.
- O modo claro pode voltar com um ADR novo: os tokens claros estão documentados no v0.
