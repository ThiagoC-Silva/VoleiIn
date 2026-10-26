# T08.2 — Conta no Resend e domínio do remetente

**Estado:** parcial, esperando a zona do DNS entrar no ar · **Depende de:** T08.1

## Objetivo

Ter conta gratuita no Resend com o domínio verificado e uma chave de API guardada, para a T08.5 só copiar os dados para o painel do Supabase.

## O que já existe

- A conferência da T08.1: o Resend exige domínio verificado e, sem ele, só envia para o e-mail do dono da conta. Não há aprovação manual de conta, ao contrário do Brevo.
- O domínio `voleiin.com.br`, registrado no Registro.br em 26/10/2026, vencendo em 26/10/2027. O DNS está nos servidores gratuitos do próprio Registro.br (`a.auto.dns.br` e `b.auto.dns.br`), editável no painel deles.
- Da documentação do Resend: host `smtp.resend.com`; portas 465 e 2465 com TLS direto, ou 25, 587 e 2587 com STARTTLS; usuário `resend`; a senha é a chave de API. A verificação do domínio costuma sair em 15 minutos, com limite de 72 horas. O Resend recomenda enviar de um subdomínio, para isolar a reputação do envio automático.
- **A zona nasce travada contra envio.** Conferido por consulta de DNS em 26/10/2026:

  | Registro | Valor publicado pelo Registro.br | Efeito |
  | --- | --- | --- |
  | `TXT voleiin.com.br` | `v=spf1 -all` | nenhum servidor está autorizado a enviar pelo domínio |
  | `MX voleiin.com.br` | `0 .` | o domínio não recebe e-mail |
  | `TXT _dmarc.voleiin.com.br` | `v=DMARC1; p=reject;` | falha na conferência manda **rejeitar** a mensagem |

  É proteção boa para domínio parado e o oposto do que a T08 precisa. O `p=reject` vale também para subdomínios, então mandar de `mail.voleiin.com.br` não contorna. Sem mexer nisso, o e-mail de cadastro é rejeitado pelo Gmail, sem nem cair no spam.

## O que falta

- [x] **[Thiago]** Vencimento do domínio em 26/10/2027 com alerta no Google Agenda. Domínio vencido derruba o login inteiro, não só o e-mail.
- [x] **[Thiago]** Criar a conta gratuita no Resend. **Não pediu cartão**: entrada pela conta do GitHub.
- [x] **Remetente decidido: o subdomínio `mail.voleiin.com.br`**, como o Resend recomenda. O domínio raiz segue trancado pelo `v=spf1 -all`, que não atrapalha o envio porque SPF não é herdado entre domínio e subdomínio.
- [x] **[Thiago]** Domínio adicionado no Resend, na região São Paulo (`sa-east-1`), com três registros gerados: um TXT de DKIM e dois CNAME.
- [x] **[Thiago]** Cinco entradas salvas no painel do Registro.br, incluindo o `_dmarc` em `p=none`.
- [ ] **[Thiago]** Esperar a verificação aparecer no Resend.
- [ ] Conferir por consulta de DNS que o publicado bate com o painel, e que o `_dmarc` está em `p=none`.
- [ ] **[Thiago]** Gerar uma chave de API no Resend e guardá-la fora do repositório: ela é a senha do SMTP.
- [ ] Anotar aqui o que não é segredo: endereço do remetente, host, porta, usuário e a data da verificação.

O `p=reject` volta na T08.7, depois de um e-mail real passar com SPF e DKIM.

## Resultado

Em andamento, 26/10/2026.

- **Conta no Resend** criada pela conta do GitHub, sem cartão de crédito.
- **Vencimento do domínio**, 26/10/2027, com alerta no Google Agenda.
- **Remetente:** subdomínio `mail.voleiin.com.br`, na região **São Paulo (`sa-east-1`)**, a mesma que o projeto do Supabase vai usar. A região aparece como bandeira ao lado do nome do domínio no painel do Resend, e se confirma no alvo do CNAME, que traz `sae1`. Trocá-la depois exigiria apagar o domínio e refazer o DNS.
- **SMTP a usar na T08.5:** host `smtp.resend.com`, porta 587 com STARTTLS, usuário `resend`, senha é a chave de API.
- **Zona salva no painel do Registro.br**, com cinco entradas. O painel não aceita `@` nem `*`, então o domínio raiz vai com o campo de nome em branco, e o DMARC fica sem `rua=mailto:`, que seria recusado:

  | Tipo | Nome | Dados | Origem |
  | --- | --- | --- | --- |
  | TXT | *(raiz)* | `v=spf1 -all` | recriado à mão, tranca o raiz contra falsificação |
  | TXT | `_dmarc` | `v=DMARC1; p=none;` | afrouxado para a configuração; volta a `p=reject` na T08.7 |
  | TXT | `resend._domainkey.mail` | chave pública de DKIM | Resend |
  | CNAME | `rsend.mail` | `rsend-sae1.forge.rmta.net` | Resend |
  | CNAME | `send.mail` | `send.forge.rmta.net` | Resend |

- **A chave de DKIM foi conferida**: decodifica como chave pública RSA de 1024 bits, com cabeçalho e expoente 65537 corretos. Não houve truncamento na cópia.
- **Pendente:** os registros estão salvos no painel mas ainda não publicados. O domínio ficou "em transição" por algumas horas depois do registro, e enquanto isso os servidores `a.auto.dns.br` e `b.auto.dns.br` continuam entregando a zona protetora padrão do Registro.br. Falta a zona entrar no ar, a verificação no Resend passar e a chave de API ser gerada.

### Achado que vale para quem repetir isto

O Registro.br publica sozinho, em domínio sem zona própria, três registros que **impedem** o envio de e-mail: `v=spf1 -all`, `MX 0 .` e `_dmarc` com `p=reject`. Eles não aparecem na tabela do painel e não dá para apagá-los; o jeito é criar as suas entradas por cima. Sem notar isso, o e-mail de cadastro seria rejeitado pelo Gmail, sem nem cair no spam.

## Pronto quando

O Resend mostra o domínio verificado, a consulta de DNS confirma os registros publicados, e a chave de API está guardada fora do repositório.

## Commit

`Registra a conta do Resend e o domínio do remetente`, só com o registro desta task.
