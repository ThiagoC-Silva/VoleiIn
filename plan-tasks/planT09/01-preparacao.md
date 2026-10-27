# T09.1 — Contas, aparelho e estado do remoto

**Estado:** a fazer · **Depende de:** —

## Objetivo

Deixar prontos, antes de qualquer e-mail gasto, os endereços, as contas no aparelho e o retrato do remoto, para que as tasks seguintes só executem.

## O que já existe

- Os dois Gmails do Thiago na lista de usuários de teste do Google (T11) e no aparelho (T07).
- O MCP do Supabase lê o remoto (T08.7).
- A versão do Auth local na T07 era v2.197.0.

## O que falta

- [ ] Confirmar com o Thiago as propostas do [README](README.md#proposto--confirmar-antes-da-execução). O que ele mudar entra no README antes de seguir.
- [ ] **[Thiago]** Escolher o endereço do **outro provedor** (Outlook, Yahoo, iCloud, de empresa…). Se for de empresa, anotar: o filtro costuma ser mais duro, e isso é um dado a mais.
- [ ] **[Thiago]** Escolher a senha descartável das contas de teste (mínimo de 8 caracteres) e dizê-la na conversa.
- [ ] **[Thiago]** Conferir que os dois Gmails continuam adicionados ao aparelho, em Configurações → Contas.
- [ ] Pelo MCP, só leitura: nenhum dos três endereços tem linha em `auth.users`, e o único usuário do remoto é o `+t087`. A consulta compara por `lower(email)`; o resultado entra no Resultado sem os endereços.
- [ ] Versão do Auth remoto: `curl -s -H "apikey: <chave pública>" https://zmokpmovphikmobynssy.supabase.co/auth/v1/health`. Anotar e comparar com a v2.197.0 do local. Se for outra, os códigos de erro da T07 podem mudar, e a T09.7 é quem mostra.
- [ ] **[Thiago]** No painel do Resend, quantos envios hoje e no mês.
- [ ] `adb devices` acha o celular sem cabo. Se não achar, `adb pair` de novo (T13).

## Resultado

## Pronto quando

Os três endereços estão escolhidos e sem conta no remoto, a senha descartável foi dita, as propostas do README foram confirmadas, e o celular aparece no `adb`.

## Commit

`Registra a preparação da validação no remoto`
