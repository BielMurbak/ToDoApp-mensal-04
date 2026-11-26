# ToDo App · Infraestrutura automatizada (PM-04)

Implantação do **ToDo App** (React + Express + MongoDB) na AWS para a Feira de Profissões. A infraestrutura é provisionada por **Terraform**, configurada e mantida por **Ansible**, com tudo acionado pelo **GitHub Actions**.

- Demanda do cliente: [docs/escopo.md](docs/escopo.md) ([PDF](escopo.pdf))
- Arquitetura, decisões e requisitos → entrega: [docs/arquitetura.md](docs/arquitetura.md)
- Custos: [docs/custos.md](docs/custos.md)
- Roteiro de evidências: [evidencias/README.md](evidencias/README.md)

```text
Navegador ──HTTPS──▶ VM app: Caddy → Nginx/React → /todos → API ──rede privada──▶ VM db: MongoDB + volume EBS → backup S3
```

## Estrutura

```text
.github/workflows/
  ci.yml        valida IaC, constrói imagens, testa o fluxo e publica no GHCR (sha-xxxxxxx)
  deploy.yml    Terraform (plan/apply/destroy) → Ansible → teste funcional pela URL pública
  ops.yml       rotinas: health, logs, restart, backup, restore-test, restore, reset-list
.github/actions/  passos reutilizados (terraform init, preparação do Ansible)
terraform/        VPC, sub-redes, NAT, security groups, 2 VMs, EBS, IAM, outputs
ansible/
  playbook.yml    prepara e mantém as VMs
  ops.yml         rotinas de operação
  roles/          os_updates, packages, docker, mongo, backup, app
scripts/          bootstrap do state, inventário, SSH temporário, teste funcional
frontend/ backend/ banco-de-dados/   aplicação (com as adaptações para nuvem)
```

## Configuração inicial (uma vez)

### 1. Chave SSH da pipeline

```bash
ssh-keygen -t ed25519 -f pm04 -N "" -C pm04-pipeline
```

Gera `pm04` (privada) e `pm04.pub` (pública). Não versione esses arquivos.

### 2. Secrets do repositório

Em **Settings → Secrets and variables → Actions → Secrets**:

| Secret | Valor |
| --- | --- |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | Credenciais da conta AWS |
| `AWS_SESSION_TOKEN` | Só AWS Academy (expira a cada ~4 h: atualize antes de rodar) |
| `SSH_PRIVATE_KEY` / `SSH_PUBLIC_KEY` | Conteúdo de `pm04` e `pm04.pub` |
| `MONGO_ROOT_PASSWORD` / `MONGO_APP_PASSWORD` | Senhas só com letras e números (ex.: `openssl rand -hex 16`) |
| `CLOUDFLARE_API_TOKEN` | Token da Cloudflare com permissão de editar o DNS do domínio (ver abaixo) |
| `DUCKDNS_TOKEN` | Alternativa gratuita sem domínio próprio: token do [duckdns.org](https://www.duckdns.org) |

### 3. Variables (opcionais)

Na aba **Variables**:

| Variable | Padrão | Uso |
| --- | --- | --- |
| `AWS_REGION` | `us-east-1` | Região |
| `INSTANCE_PROFILE_NAME` | (vazio: o Terraform cria) | AWS Academy: `LabInstanceProfile` |
| `APP_DOMAIN` | `<ip>.sslip.io` | Domínio da aplicação, ex.: `mensal.belottimoveis.com.br` (a pipeline aponta o DNS para o IP sozinha) |
| `ACME_EMAIL` | (vazio) | E-mail do certificado; habilita o ZeroSSL como reserva do Let's Encrypt |
| `ADMIN_CIDRS` | `[]` | IPs com SSH de diagnóstico, ex.: `["200.1.2.3/32"]` |
| `ENABLE_NAT_GATEWAY` | `true` | `false` desliga o NAT (economia; ver custos) |

### 4. Domínio HTTPS

A cada `apply` a VM ganha um IP novo; a pipeline (`scripts/dns-update.sh`) atualiza o DNS sozinha e o Caddy emite o certificado.

**Domínio na Cloudflare (usado pelo grupo: `mensal.belottimoveis.com.br`)**

1. Cloudflare → ícone do perfil → **My Profile → API Tokens → Create Token**.
2. Modelo **Edit zone DNS** → em *Zone Resources* escolha **Specific zone → belottimoveis.com.br** → **Continue → Create Token**.
3. Copie o token para o Secret `CLOUDFLARE_API_TOKEN`.
4. Variables: `APP_DOMAIN = mensal.belottimoveis.com.br` e `ACME_EMAIL` com o e-mail do grupo.

O registro é criado como **DNS only** (nuvem cinza), porque o HTTPS é feito pelo Caddy na VM. Se o nome já for um CNAME, a pipeline para com erro em vez de apagá-lo: remova o registro antigo no painel.

**Sem domínio próprio:** crie um subdomínio grátis em [duckdns.org](https://www.duckdns.org), use `DUCKDNS_TOKEN` e `APP_DOMAIN = <nome>.duckdns.org`. Sem nenhum dos dois, o endereço é `<ip>.sslip.io` (pode bater no limite de certificados do Let's Encrypt).

### 5. Publicar as imagens

Um push na `main` roda o **CI**, que testa e publica `ghcr.io/<usuario>/todo-backend` e `todo-frontend` com as tags `sha-xxxxxxx` e `latest`. A tag aparece no Summary do run.

## Pipelines

### Infraestrutura (Terraform + Ansible)

**Actions → Infraestrutura (Terraform + Ansible) → Run workflow**

| Parâmetro | Efeito |
| --- | --- |
| `environment` | `dev` / `homolog` / `prod`; cada um tem state e recursos próprios |
| `action` | `plan` só mostra as mudanças · `apply` cria/atualiza · `destroy` faz o backup final e remove tudo |
| `instance_name` | Nome base das VMs (`vm-pm04` → `vm-pm04-app` e `vm-pm04-db`); mudar só renomeia, sem recriar |
| `app_instance_type` / `db_instance_type` | Tamanho das VMs (alteração in-place, sem recriar) |
| `app_image_tag` | Versão implantada (`sha-xxxxxxx` recomendado) |
| `force_pull` | Baixa a imagem de novo mesmo com a mesma tag (para `latest`) |
| `update_os` | Aplica atualizações do Ubuntu (reinicia se necessário) |
| `extra_packages` | Pacotes extras, ex.: `git,tree,nmap` |
| `confirm_destroy` | Para `destroy`, digite o nome do ambiente |

Sequência: `terraform init/fmt/validate/plan` → `apply` (só se houver mudança) → inventário gerado do `terraform output` → `ansible-playbook` → teste funcional (cadastrar, concluir, reabrir, excluir) pela URL HTTPS.

**Voltar para a versão anterior:** rode `apply` com a tag `sha-…` anterior (listada nos runs do CI).

### Operação (rotinas do dia a dia)

**Actions → Operação (rotinas do dia a dia) → Run workflow**. Não altera a infraestrutura.

| Rotina | O que faz | Quando usar |
| --- | --- | --- |
| `health` | Contêineres, versão, `/health` público, portas do banco fechadas, tarefas no banco | Antes de cada apresentação / algo estranho |
| `logs` | Últimas linhas da aplicação, do MongoDB e do backup | Diagnóstico |
| `restart-app` | Reinicia Caddy, Nginx e API (dados intactos) | Página fora do ar / erro 502 |
| `restart-db` | Reinicia o MongoDB (dados ficam no volume) | `/health` com `db: down` |
| `backup` | Backup imediato (local + S3) | Antes de mudanças |
| `restore-test` | Restaura o último backup do S3 num MongoDB temporário isolado e compara | Provar que o backup funciona |
| `restore` | Substitui o banco pelo último backup (faz backup antes); `confirm=RESTAURAR` | Lista apagada/estragada |
| `reset-list` | Limpa a lista e coloca as tarefas de demonstração (faz backup antes); `confirm=LIMPAR` | Antes de cada apresentação |

## Manual rápido para os alunos

1. **Ligar o ambiente:** Infraestrutura → `apply` com a última tag do CI. A URL aparece no fim do Summary.
2. **Verificar:** Operação → `health`. Tudo ok = contêineres `healthy`, `db: up`, portas FECHADAS.
3. **Preparar a apresentação:** Operação → `reset-list` com `confirm=LIMPAR`.
4. **Durante a feira:** a lista é a mesma para todos e não atualiza sozinha (recarregue a página). Avise os visitantes.
5. **Se der problema:**
   - página não abre → `health`, depois `restart-app`
   - "erro ao carregar tarefas" → `health`; se `db: down`, `restart-db`
   - ainda com erro → `logs` e procure `Erro ao conectar` ou `502`
   - lista apagada → `restore` com `confirm=RESTAURAR`
6. **Atualizar a aplicação:** push na `main` → CI gera `sha-…` → Infraestrutura `apply` com essa tag.
7. **Encerrar após a feira:** Infraestrutura → `destroy`, `confirm_destroy=<ambiente>`. O último backup fica no S3 por 14 dias. Veja em [custos](docs/custos.md) o que continua existindo.

> Reiniciar (`restart-*`), limpar a lista (`reset-list`) e remover a infraestrutura (`destroy`) são operações diferentes. Só `destroy` apaga as VMs.

## Executar localmente

Pré-requisitos: Docker com Docker Compose.

```bash
docker compose up --build -d --wait
```

Acesse **http://localhost**. A API responde no mesmo endereço (`/todos`) e também em `http://127.0.0.1:5000`. Teste do fluxo completo:

```bash
bash scripts/smoke-test.sh http://localhost
```

Para parar, use `docker compose down`. Para apagar também os dados, use `docker compose down -v`. As senhas locais são de demonstração; para trocar, copie `.env.example` para `.env`.

---

Aplicação base: [LaercioMLB/todo-app](https://github.com/LaercioMLB/todo-app), laboratórios de Engenharia de Software do professor Laércio.
