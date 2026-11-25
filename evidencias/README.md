# Evidências

Salve aqui prints e logs (sem senhas) de cada execução. O **Summary** de cada run do GitHub Actions já traz o plan resumido, o inventário e o PLAY RECAP; dá para salvar como PDF.

## Testes obrigatórios do PM-04

| Cenário | Como executar | O que registrar |
| --- | --- | --- |
| 1 · Criação inicial | Infraestrutura: `apply`, `dev`, `t3.micro`/`t3.micro`, tag `sha-xxxxxxx` | Plan "N to add", apply, PLAY RECAP, URL abrindo, teste funcional verde |
| 2 · Atualização | Mesmo ambiente com `app_instance_type=t3.small` + `extra_packages=git,tree,nmap` + `update_os=true` (ou nova tag) | Plan "1 to change" (sem destroy), tarefas `changed` no Ansible, `instance_type` novo no console |
| 3 · Reexecução | Repetir o cenário 2 com os mesmos parâmetros (`force_pull=false`) | "No changes" no Terraform e `changed=0` no PLAY RECAP |
| Validação da demanda | `docs/arquitetura.md`, seção 5 | Tabela de requisitos → recursos |

## Critérios de aceite da demanda

| Critério | Evidência |
| --- | --- |
| ACE-01 Reprodução | Run do cenário 1 a partir do zero |
| ACE-02 Duas VMs | Summary "Inventário" + console EC2 |
| ACE-03 Isolamento | Operação `health`: portas 27017/5000 FECHADAS no IP público; VM db sem IP público |
| ACE-04 Aplicação pública | Celular (4G) abrindo a URL: cadastrar, concluir, reabrir, excluir, recarregar |
| ACE-05 Persistência | Criar tarefa → `restart-db` → tarefa continua; deploy de nova tag → tarefa continua |
| ACE-06 Automação | Runs do CI (imagem `sha-…`) e da Infraestrutura |
| ACE-07 Recuperação | Operação `restore-test`: contagem restaurada × banco da demonstração |
| ACE-08 Operação | Runs de `health`, `logs`, `restart-app`; buscar a senha no log e não encontrar |
| ACE-09 Custos | `docs/custos.md` |
| ACE-10 Transferência | Alunos executando `reset-list` e `health` pelo manual |
