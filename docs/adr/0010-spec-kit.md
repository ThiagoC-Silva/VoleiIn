# 0010. Spec Kit como único framework de especificação

- **Status:** Aceito
- **Data:** 2026-11-06

## Contexto
O código é escrito com ajuda de um agente de IA, que rende mais com tarefas delimitadas e especificadas. Há vários frameworks para isso, e combinar mais de um gera instruções conflitantes.

## Decisão
GitHub Spec Kit, rodado uma vez por fatia (ou por etapa, nas fatias grandes): `specify`, `plan`, `tasks`, `implement` e `converge` (`trabalho-com-agente.md`, seção 3). `docs/` continua sendo a fonte da verdade: o `spec.md` cita RFs e RNs, sem copiar o texto.

## Alternativas descartadas
- **OpenSpec ou BMAD:** cumprem o mesmo papel, e usar mais de um gera instruções conflitantes.
- **Sem framework:** cada sessão inventaria o próprio formato de plano.

## Consequências
- Exige Python 3.11+ e `uv` (`setup.md`, seção 3).
- O Spec Kit é testado num repositório descartável antes da fatia 1.
- Se um `spec.md` divergir de `docs/`, vale `docs/`.
