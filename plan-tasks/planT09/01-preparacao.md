# T09.1 — Contas, aparelho e estado do remoto

**Estado:** feito · **Depende de:** —

## Objetivo

Deixar prontos, antes de qualquer e-mail gasto, os endereços, as contas no aparelho e o retrato do remoto, para que as tasks seguintes só executem.

## O que já existe

- Os dois Gmails do Thiago na lista de usuários de teste do Google (T11) e no aparelho (T07).
- O MCP do Supabase lê o remoto (T08.7).
- A versão do Auth local na T07 era v2.197.0.

## O que falta

- [x] Confirmar com o Thiago as propostas do [README](README.md#decidido-em-2026-10-27). O que ele mudar entra no README antes de seguir.
- [x] **[Thiago]** Escolher o endereço do **outro provedor** (Outlook, Yahoo, iCloud, de empresa…). Se for de empresa, anotar: o filtro costuma ser mais duro, e isso é um dado a mais.
- [x] **[Thiago]** Escolher a senha descartável das contas de teste (mínimo de 8 caracteres) e dizê-la na conversa.
- [x] **[Thiago]** Conferir que os dois Gmails continuam adicionados ao aparelho, em Configurações → Contas.
- [x] Pelo MCP, só leitura: nenhum dos três endereços tem linha em `auth.users`, e o único usuário do remoto é o `+t087`. A consulta compara por `lower(email)`; o resultado entra no Resultado sem os endereços.
- [x] Versão do Auth remoto: `curl -s -H "apikey: <chave pública>" https://zmokpmovphikmobynssy.supabase.co/auth/v1/health`. Anotar e comparar com a v2.197.0 do local. Se for outra, os códigos de erro da T07 podem mudar, e a T09.7 é quem mostra.
- [x] **[Thiago]** No painel do Resend, quantos envios hoje e no mês.
- [x] `adb devices` acha o celular sem cabo. Se não achar, `adb pair` de novo (T13).

## Resultado

Feito em 2026-10-27.

- **Propostas do README:** confirmadas sem mudança; o que foi dito explicitamente está no [README](README.md#decidido-em-2026-10-27).
- **Outro provedor:** uma caixa `@outlook.com` do Thiago, filtrada pela Microsoft. Uma conta Microsoft com login Gmail não serviria: a caixa continua no Gmail.
- **Gmail 1** é o principal do Thiago, e o **Gmail 2** o secundário, o mesmo do `+t087`. Os dois estão no aparelho, pelo `adb shell dumpsys account`, e são as duas únicas contas Google dele.
- **Senha descartável:** dita na conversa, fora daqui. Vale para as contas criadas no celular (T09.4, T09.6 e T09.8); o script usa as senhas fixas dele.
- **Remoto** antes da T09, pelo MCP: um usuário (o `+t087`, confirmado, com `pessoa` e uma identidade), uma `pessoa`, nenhum `dispositivo_push`, uma sessão. Nenhum dos endereços da T09 tem conta.
- **Auth remoto:** v2.197.0, a mesma do local na T07.
- **Resend antes da T09:** 3 envios no dia e no mês, os da T08.7.
- **`adb devices`:** o celular aparece duas vezes, pelo IP e pelo nome do mDNS, ambos `device`. Os comandos usam `-s` com o IP.

## Pronto quando

Os três endereços estão escolhidos e sem conta no remoto, a senha descartável foi dita, as propostas do README foram confirmadas, e o celular aparece no `adb`.

## Commit

`Registra a preparação da validação no remoto`
