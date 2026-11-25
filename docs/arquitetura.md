# Arquitetura e decisões técnicas

**Demanda:** [escopo.md](escopo.md), implantação do ToDo App para a Feira de Profissões.
**Projeto:** PM-04, automação de infraestrutura com Terraform, Ansible e CI/CD.

## 1. Análise da demanda

| O sistema precisa de | Componente entregue |
| --- | --- |
| Interface React acessível pelo navegador | Nginx servindo o build React (imagem `todo-frontend`) |
| API Express (`/todos`, `/todos/:id`) no mesmo endereço | Nginx encaminha `/todos` e `/health` para a API (imagem `todo-backend`) |
| MongoDB com dados de demonstração | `mongo:7.0.14` em VM exclusiva, usuário próprio da aplicação |
| Endereço público HTTPS | Caddy com certificado automático (Let's Encrypt) em `<nome>.duckdns.org` (gratuito) ou `<ip>.sslip.io` |
| Preservar as tarefas | Volume EBS separado + backups no S3 |
| Operação pelos alunos | Pipelines de operação (saúde, logs, reinício, backup, restauração, preparar lista) |

## 2. Arquitetura

```text
                    Internet
                       │ HTTPS 443 (HTTP 80 → redireciona)
┌──────────────────────┼──────────────── VPC 10.20.0.0/16 ─────────────────────────────┐
│  Sub-rede pública    ▼                       │  Sub-rede privada (sem IP público)   │
│  ┌─────────────────────────────────────┐     │  ┌─────────────────────────────────┐ │
│  │ VM app (Elastic IP)                 │     │  │ VM db  10.20.2.10               │ │
│  │  Caddy :443 → Nginx/React :80       │ 27017  │  mongo:7.0.14                   │ │
│  │             └ /todos → API :5000 ───┼─────┼─▶│  /data/mongo = EBS gp3 (dados)  │ │
│  └─────────────────────────────────────┘     │  │  cron: mongodump → S3           │ │
│        SG app: 80/443 público, 22 restrito   │  └─────────────────────────────────┘ │
│  NAT Gateway ◀── saída da VM db (pacotes)    │   SG db: 27017 e 22 só do SG app     │
│  Endpoint S3 (gateway, gratuito) ◀── backups                                          │
└───────────────────────────────────────────────────────────────────────────────────────┘
  Fora do ambiente (sobrevivem ao destroy): bucket do Terraform State · bucket de backups · imagens no GHCR
```

Fluxo de uma requisição: navegador → Caddy (TLS) → Nginx → `/todos` → API → MongoDB pela rede privada.

## 3. Decisões e justificativas

| Decisão | Escolha | Por quê |
| --- | --- | --- |
| Provedor | AWS, `us-east-1` | Conta da disciplina; região mais barata e com todos os serviços usados |
| CI/CD | GitHub Actions | Repositório já está no GitHub; GHCR gratuito para as imagens; `workflow_dispatch` com parâmetros |
| VMs | 2× `t3.micro` (Ubuntu 24.04) | Demonstração com poucos usuários simultâneos; a pipeline troca para `t3.small` sem recriar a VM |
| Banco isolado | Sub-rede privada, sem IP público, SG aceita 27017 só do SG da app | REQ-02: banco nunca exposto na internet |
| Saída da VM do banco | NAT Gateway (desligável com `ENABLE_NAT_GATEWAY=false`) | Instalar pacotes/imagens sem IP público; é o maior custo, por isso pode ser desligado depois da configuração |
| Persistência | EBS gp3 separado, montado em `/data/mongo` | REQ-04: recriar a VM ou o contêiner não apaga dados |
| Backup | `mongodump` a cada 6h → local (7 dias) + S3 (14 dias), via instance profile | Cópia fora da VM sem chaves gravadas na máquina |
| HTTPS | Caddy + DuckDNS | Certificado válido sem comprar domínio; a pipeline atualiza o DNS com o IP de cada `apply`. Sem DuckDNS cai para `<ip>.sslip.io`, sujeito ao limite de certificados compartilhado |
| Acesso às VMs | Somente chave SSH; SSH do runner liberado só durante a execução; VM do banco via bastion | REQ-03: superfície mínima de administração |
| Segredos | GitHub Secrets → variáveis de ambiente → arquivos `.env` 0600 nas VMs, tarefas com `no_log` | Nada no código nem nos logs |
| State | S3 com versionamento, criptografia e trava (`use_lockfile`), um arquivo por ambiente | Proteção e recuperação do state; execuções concorrentes bloqueadas |
| Imagens | Tag `sha-<commit>` imutável + `latest` | Versões identificáveis; voltar versão = rodar a pipeline com a tag anterior |
| Idempotência | AMI ignorada após criação, regras de SG em recursos separados, tarefas Ansible declarativas | Cenário 3: `No changes` no Terraform e `changed=0` no Ansible |

## 4. Adaptações feitas na aplicação (escopo, item 5)

| Problema na base | Adaptação |
| --- | --- |
| Frontend chamava `http://localhost:5000` | Usa caminho relativo `/todos` (ou `REACT_APP_API_URL`) |
| Nginx não encaminhava a API | `frontend/nginx/default.conf.template`: `/todos` e `/health` → `API_UPSTREAM` |
| URL e senha do Mongo fixas no código | `MONGO_URL` vem do ambiente; API usa usuário `todo-app` só com `readWrite` |
| Sem verificação de prontidão | Reconexão automática ao banco + `GET /health` (testa o banco) + `HEALTHCHECK` nas imagens |
| CORS aberto | `CORS_ORIGIN` restringe à URL pública |
| `mongo:latest`, porta do banco publicada, sem volume | `mongo:7.0.14`, porta só no IP privado, volume persistente |

## 5. Requisitos da demanda → entrega

| Requisito | Como foi atendido | Onde |
| --- | --- | --- |
| REQ-01 Servidores | 2 VMs; MongoDB sozinho na VM db | `terraform/main.tf` |
| REQ-02 Rede privada | Sub-rede privada, SG db só aceita o SG app, porta publicada só no IP privado | `terraform/security.tf`, `roles/mongo` |
| REQ-03 Acessos | Chave SSH, SSH temporário do runner, bastion, usuário próprio no banco, Secrets | `scripts/runner-ssh.sh`, `banco-de-dados/init-mongo.js` |
| REQ-04 Persistência | EBS separado, backup automático, teste de restauração isolado | `roles/mongo`, `roles/backup`, `ops.yml` |
| REQ-05 Publicação | URL HTTPS única para interface e API | `roles/app` (Caddy + Nginx) |
| REQ-06 Disponibilidade | `restart: unless-stopped`, healthchecks, verificação pública ao fim do deploy, rotinas de diagnóstico | Dockerfiles, `roles/app`, `ops.yml` |

| Operação (escopo, item 9) | Pipeline |
| --- | --- |
| Validar e planejar | Infraestrutura `action=plan` · CI (fmt/validate/syntax-check) |
| Provisionar e configurar | Infraestrutura `action=apply` |
| Implantar e atualizar | CI publica `sha-xxxxxxx` → Infraestrutura com `app_image_tag` |
| Manter e diagnosticar | Operação: `health`, `logs`, `restart-app`, `restart-db` |
| Proteger e recuperar | cron de backup · Operação: `backup`, `restore-test`, `restore` |
| Desativar | Infraestrutura `action=destroy` (backup final antes) |

## 6. Requisitos do PM-04 → entrega

| PM-04 | Entrega |
| --- | --- |
| Pipeline manual com parâmetros | `.github/workflows/deploy.yml`: `environment`, `action`, `instance_name`, `app_instance_type`, `db_instance_type`, `app_image_tag`, `force_pull`, `update_os`, `extra_packages` |
| Terraform e Ansible em sequência | Job `terraform` → artefato `tf-outputs.json` → job `ansible` (inventário gerado do output) |
| Logs claros e parada no erro | `set -e`/`pipefail`, plan resumido no Summary, PLAY RECAP no Summary |
| Terraform: VM, rede, regras, variáveis, state | `terraform/*.tf`, backend S3 |
| Atualizar sem recriar | Tipo de VM muda in-place (stop/start); Elastic IP mantém o endereço |
| Ansible: Docker, contêineres, tags, SO, pacotes, idempotência | Roles `os_updates`, `packages`, `docker`, `mongo`, `app`, `backup` |

## 7. Limitações e premissas

- Uma zona de disponibilidade: se a zona cair, a aplicação para. Para a feira o risco é aceitável e o custo menor.
- A lista é compartilhada entre todos os visitantes (comportamento da aplicação); use `reset-list` antes de cada apresentação.
- Senhas do banco só são aplicadas na primeira inicialização do volume; trocar depois exige recriar o volume ou alterar no Mongo.
- Data da feira, público esperado e domínio não foram informados: assumimos até ~50 visitantes simultâneos e o domínio gratuito do DuckDNS.
- Com o NAT desligado, a VM do banco não recebe atualizações do SO nem novas imagens; os backups continuam pelo endpoint S3.
