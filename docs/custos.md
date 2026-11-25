# Estimativa de custos

> **Premissas:** AWS `us-east-1`, preços on-demand em USD da página de preços da AWS, Linux, uso 24h.
> Valores de referência; **conferir na [AWS Pricing Calculator](https://calculator.aws/) na data da entrega** e registrar a data da consulta.
> Créditos (AWS Academy / plano gratuito) aparecem separados e não reduzem o custo de referência.

## Custo mensal de referência (730 h)

| Item | Qtde | Preço unitário | Mês (USD) |
| --- | --- | --- | --- |
| VM app `t3.micro` (2 vCPU, 1 GiB) | 1 | 0,0104/h | 7,59 |
| VM db `t3.micro` (2 vCPU, 1 GiB) | 1 | 0,0104/h | 7,59 |
| EBS gp3 (2 × 16 GB sistema + 10 GB dados) | 42 GB | 0,08/GB-mês | 3,36 |
| IPv4 público (Elastic IP da app + IP do NAT) | 2 | 0,005/h | 7,30 |
| NAT Gateway (hora) | 1 | 0,045/h | 32,85 |
| NAT Gateway (dados processados, ~2 GB) | 2 GB | 0,045/GB | 0,09 |
| S3 (state + backups, < 1 GB) | – | 0,023/GB-mês | < 0,10 |
| Tráfego de saída para a internet | < 100 GB | primeiros 100 GB/mês gratuitos | 0,00 |
| Endpoint S3 (gateway), Let's Encrypt, DuckDNS, GitHub Actions/GHCR (repo público) | – | gratuito | 0,00 |
| **Total com NAT** | | | **≈ 58,9** |
| **Total sem NAT** (desligado após configurar) | | | **≈ 22,3** |

Com `t3.small` na VM da aplicação (cenário de atualização): + 7,59/mês.

## Custo do período da feira

Hipótese: 7 dias de preparação e ensaio + 1 dia de feira + 1 dia para encerramento = **9 dias (216 h)**, com a infraestrutura ligada o tempo todo.

| Item | USD |
| --- | --- |
| 2 VMs `t3.micro` (216 h) | 4,49 |
| EBS 42 GB (9 dias) | 1,01 |
| 2 IPv4 públicos (216 h) | 2,16 |
| NAT Gateway (216 h) | 9,72 |
| S3 e tráfego | < 0,10 |
| **Total do período** | **≈ 17,5** |

Para economizar: criar o ambiente só para os ensaios e destruir no fim do dia (os backups ficam no S3) ou desligar o NAT depois da primeira configuração (≈ 11,6 no período).

## Uso real do grupo (crédito de US$ 5)

Ambiente completo ≈ US$ 0,08/h. Estratégia adotada: criar, testar e destruir na mesma sessão.

| Sessão | Horas | USD |
| --- | --- | --- |
| Noite de testes (cenários 1, 2 e 3 + evidências) | ~4 | ~0,32 |
| Apresentação (recriar, demonstrar, destruir) | ~3 | ~0,24 |
| **Total previsto** | | **~0,60** |

O crédito cobre ~60 h de ambiente ligado; esquecer o ambiente ligado por 3 dias consome tudo, por isso `destroy` faz parte de cada sessão.

## O que continua gerando cobrança após o `destroy`

| Recurso | Motivo de ficar | Custo |
| --- | --- | --- |
| Bucket `pm04-todo-backups-<conta>` | Último backup das tarefas (expira em 14 dias) | centavos |
| Bucket `pm04-todo-tfstate-<conta>` | Histórico do state (versionado) | centavos |
| Imagens no GHCR | Versões publicadas | gratuito (repo público) |

Para zerar: esvaziar e apagar os dois buckets no console S3 depois de conferir que os backups não são mais necessários.

## Fatores de variação

- Mais visitantes → trocar a VM da app para `t3.small` pela pipeline (sem recriar).
- Tráfego acima de 100 GB/mês passa a ser cobrado (~0,09/GB).
- Instâncias `t3` acumulam créditos de CPU; uso alto contínuo pode gerar cobrança de "unlimited" (pequena).
