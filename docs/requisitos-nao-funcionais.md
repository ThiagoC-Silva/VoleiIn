# Requisitos Não Funcionais

> Decisões de 06/11/2026. Base: `requisitos.md`, `regras-negocio.md`, `modelo-dados.md` e `stacks.md`.
> Os limites e preços de terceiros foram consultados nessa data e podem mudar. Os custos são estimativas, ainda não medidas.

## 1. Resumo

| ID | Tema | Decisão |
|----|------|---------|
| RNF01 | Versão mínima do Android | Android 10 (API 29) |
| RNF02 | Versão alvo do Android | API 36 ou superior, conforme a exigência vigente da Google Play |
| RNF03 | Escala nos primeiros 12 meses | Até 100 pessoas e 5 grupos |
| RNF04 | Velocidade | Abrir o app em até 3 s, carregar a lista em até 2 s, ler o comprovante em até 30 s |
| RNF05 | Acessibilidade | Nível essencial (seção 5) |
| RNF06 | Idioma e formatos | pt-BR, reais e fuso `America/Fortaleza` |
| RNF07 | Uso sem internet | Nada funciona sem conexão |
| RNF08 | Disponibilidade | Sem meta formal |
| RNF09 | Backup | Sem backup |
| RNF10 | Custo mensal após o lançamento | Meta de até US$ 5, com alerta ao se aproximar |
| RNF11 | Privacidade | Conforme o `stacks.md`, seções 12 e 13 |

## 2. Android

- **RNF01. Versão mínima:** `minSdk = 29`. Quem tem um celular com versão anterior não consegue instalar o app pela Google Play e, portanto, não entra em listas nem envia comprovantes pelo app.
- **RNF02. Versão alvo:** `targetSdk = 36` ou superior. A Google Play exige API 36 para apps novos e atualizações desde 31/08/2026. Esse valor acompanha a exigência da loja a cada ano.
- **Testes:** os testes de integração (`stacks.md`, seção 11) rodam nas duas pontas: API 29 e a versão alvo.

## 3. Escala

**RNF03.** Referência para dimensionar testes de carga, índices e custo:

| Item | Valor |
|------|-------|
| Pessoas com conta | Até 100 |
| Grupos | Até 5 |
| Jogos | Até 2 por semana em cada grupo, cerca de 40 por mês |
| Valores a pagar | Até 11 por jogo de 12 vagas, cerca de 440 por mês |
| Pico de pessoas conectadas ao mesmo tempo | Até 100 |

Esta decisão dimensiona a operação. Ela não muda a premissa de arquitetura do `stacks.md` (seção 1), nem os limites livres de vagas e de valor (RN05, RN06).

**Folga nos limites do plano grátis do Supabase:**

| Limite do plano grátis | Uso esperado | Situação |
|------------------------|--------------|----------|
| 2 projetos ativos | 1, a produção; desenvolvimento e homologação rodam no Supabase local (`stacks.md`, seção 10.1, ADR 0011) | Cabe |
| 50.000 usuários ativos por mês | Até 100 | Cabe |
| 500 MB de banco | Registros de texto de até 100 pessoas | Cabe; acompanhar pelo painel |
| 1 GB de Storage | Fotos de até 2 MB (RN106) e comprovantes guardados por 30 dias após a decisão (RN91) | Cabe no uso típico. Pior caso teórico: 440 comprovantes de 10 MB (4,4 GB) estouram o limite |
| 200 conexões simultâneas de Realtime | Até 100 | Cabe |

## 4. Velocidade

**RNF04.** Metas para build de release em um celular intermediário com Android 10 e internet 4G, cumpridas em ao menos 9 de cada 10 medições:

| Operação | Meta | Como medir |
|----------|------|------------|
| Abrir o app | Até 3 s | Do toque no ícone, com o app fechado e sessão ativa, até a primeira tela com dados |
| Carregar a lista de presença | Até 2 s | Do toque no jogo até a lista visível |
| Ler o comprovante | Até 30 s | Do fim do envio do arquivo até o resultado na tela. O tempo de envio não conta, porque varia com o tamanho do arquivo e a conexão |

O tratamento de leitura que passa do tempo limite será definido no documento de leitura de comprovantes (`plan-docs.md`, seção 4.4).

## 5. Acessibilidade

**RNF05.** Nível essencial, aplicado desde a primeira tela:

| Item | Requisito |
|------|-----------|
| Tamanho de fonte | Respeitar a fonte do sistema até 150%, sem cortar texto nem quebrar a tela |
| Contraste | Mínimo de 4,5:1 para texto normal |
| Status | Sempre com texto, nunca só pela cor (Pago, Pendente, Aberto, Confirmado etc.) |
| Áreas de toque | Mínimo de 48 × 48 dp |
| Leitor de tela | Botões, ícones e imagens com rótulo para o TalkBack |

**Fora do escopo:** fonte acima de 150% e testes completos com TalkBack.

## 6. Idioma e formatos

**RNF06.**

- **Idioma:** somente pt-BR.
- **Moeda:** reais, no formato `R$ 20,84`, com cálculo em centavos inteiros (RN04).
- **Datas e horas:** `dd/mm/aaaa` e relógio de 24 horas, exibidas em `America/Fortaleza` e gravadas em UTC (RN01).
- **Exceção:** a hora lida dos comprovantes segue `America/Sao_Paulo` (RN88).

## 7. Uso sem internet

**RNF07.** O app não funciona sem conexão:

- Sem conexão, o app mostra uma tela de "sem conexão" com a opção de tentar de novo.
- Nenhum dado de jogos, listas, valores ou perfis é guardado no aparelho para consulta offline.
- Nenhuma ação fica em fila para envio posterior. Isso também é exigido pela RN02: as comparações de tempo usam o relógio do servidor no momento da gravação.
- A sessão continua ativa (RF05): quando a conexão volta, o usuário não precisa entrar de novo.

## 8. Disponibilidade e backup

- **RNF08. Disponibilidade:** sem meta formal. O serviço depende do Supabase no plano grátis e funciona pelo melhor esforço possível. Quando o servidor não responde, o app mostra uma mensagem de erro com a opção de tentar de novo.
- **RNF09. Backup:** sem backup do banco. **Risco aceito:** um erro grave ou uma perda do banco pode apagar definitivamente o histórico de valores, multas e comprovantes.
- **Pausa do plano grátis:** o Supabase pausa o projeto após 1 semana sem uso. Enquanto a produção estiver pausada, o app e as tarefas agendadas (`stacks.md`, seção 7) ficam parados. Conta como uso a atividade de consultas no banco vinda de usuários, pela API ou pelo app, com algumas por dia ao longo da semana; o `pg_cron` não conta, e a Supabase avisa por e-mail uma semana antes (confirmado na fatia 1, em 12/11/2026, na documentação oficial de *project pausing*). Enquanto o app não tiver uso diário, a produção pode ser mantida acordada por uma requisição externa semanal ao banco, ou reativada pelo painel quando precisar.
- **Migrações:** como não há backup nem banco remoto de homologação, depois do lançamento toda migração é ensaiada antes com uma cópia dos dados da produção, restaurada no Supabase local. A cópia fica guardada na máquina do responsável até a próxima migração, como foto do banco de antes da mudança. Não é backup contínuo e não muda a RNF09 (`setup.md`, seção 9.2, ADR 0011).

## 9. Custo

**RNF10.** Meta de **até US$ 5 por mês** após o lançamento. Não inclui o domínio nem a taxa de cadastro da Google Play.

| Serviço | Custo mensal esperado |
|---------|-----------------------|
| Supabase, plano grátis | US$ 0 |
| Firebase Cloud Messaging | US$ 0 |
| Cloudflare Pages | US$ 0 (uso comercial a confirmar, `stacks.md`, seção 14) |
| Resend, plano grátis (e-mails) | US$ 0 |
| Claude API, leitura de comprovantes | Estimativa na tabela abaixo |

**E-mails:** o serviço padrão do Supabase só envia para a equipe do projeto, com limite de 2 mensagens por hora. Por isso, a confirmação de cadastro (RF02), a recuperação de senha (RF06) e a troca de e-mail (RF106) exigem um provedor SMTP próprio, que será o **Resend**, enviando pelo subdomínio verificado `mail.voleiin.com.br`. O plano grátis permite 3.000 e-mails por mês, 100 por dia e 3 domínios, o que cabe na escala da seção 3. O próximo plano custa US$ 20 por mês e não cabe na meta.

**Estimativa da Claude API**, com cerca de 2.000 tokens de entrada e 300 de saída por leitura e sem considerar o raciocínio do modelo, que pode aumentar o custo:

| Modelo | Por leitura | 88 leituras por mês (1 grupo) | 440 leituras por mês (5 grupos) |
|--------|-------------|-------------------------------|---------------------------------|
| Opus 5.5 | US$ 0,014 | US$ 1,23 | US$ 6,16 |
| Sonnet 5.5 | US$ 0,007 | US$ 0,62 | US$ 3,08 |
| Haiku 5.5 | US$ 0,00035 | US$ 0,03 | US$ 0,15 |

Os números assumem uma leitura por valor a pagar. Com as 3 leituras permitidas (RN86), o pior caso é o triplo. A escolha do modelo e a medição do custo real ficam no documento de leitura de comprovantes (`plan-docs.md`, seção 4.4).

**Ao chegar perto da meta:**

- A meta não é um limite rígido. **A leitura automática continua funcionando** mesmo que o gasto do mês passe de US$ 5.
- O responsável recebe um alerta quando o gasto do mês com a Claude API chegar a **US$ 4**. O mecanismo do alerta será definido na fatia 6.
- A conta da Claude API não deve ter limite de gasto igual à meta: ao atingi-lo, as leituras falhariam e os comprovantes iriam para análise manual, o contrário desta decisão.

## 10. Privacidade

**RNF11.** Valem as regras de visibilidade, retenção, anonimização e proteção contra abuso do `stacks.md` (seções 12 e 13). Como não há uso offline (RNF07), dados pessoais de outros usuários não ficam guardados no aparelho para consulta offline.

## 11. Quando revisar

Revisar este documento se ocorrer qualquer um destes casos:

- O app passar de 100 pessoas ou 5 grupos.
- O uso chegar a 80% de algum limite do plano grátis (seção 3).
- O gasto mensal passar de US$ 5 por dois meses seguidos.
- Houver perda de dados ou pausa da produção.
- A Google Play mudar a versão alvo exigida.
