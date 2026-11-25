#!/usr/bin/env bash
# Teste do fluxo funcional pelo endereço público: listar, cadastrar, concluir, reabrir e excluir.
# A tarefa de teste é removida no final; a lista da demonstração fica como estava.
# Uso: scripts/smoke-test.sh https://<dominio>
set -euo pipefail

BASE="${1%/}"
CURL=(curl -fsS --retry 5 --retry-delay 3 --retry-all-errors -H 'Content-Type: application/json')

echo "== Página inicial"
"${CURL[@]}" "$BASE/" | grep -q '<div id="root">' && echo "OK: interface React entregue"

echo "== Saúde (API + banco)"
"${CURL[@]}" "$BASE/health" | tee /dev/stderr | jq -e '.db == "up"' >/dev/null

echo "== Listar"
BEFORE=$("${CURL[@]}" "$BASE/todos" | jq length)
echo "Tarefas antes: $BEFORE"

echo "== Cadastrar"
TEXT="teste-pipeline-$(date +%s)"
ID=$("${CURL[@]}" -X POST "$BASE/todos" -d "{\"text\":\"$TEXT\"}" | jq -r '._id')
echo "Criada: $ID ($TEXT)"

echo "== Concluir"
"${CURL[@]}" -X PATCH "$BASE/todos/$ID" | jq -e '.completed == true' >/dev/null && echo "OK: concluída"

echo "== Reabrir"
"${CURL[@]}" -X PATCH "$BASE/todos/$ID" | jq -e '.completed == false' >/dev/null && echo "OK: reaberta"

echo "== Recarregar e conferir"
"${CURL[@]}" "$BASE/todos" | jq -e --arg id "$ID" 'any(.[]; ._id == $id)' >/dev/null && echo "OK: tarefa persistida no banco"

echo "== Excluir"
"${CURL[@]}" -X DELETE "$BASE/todos/$ID" | jq -r '.message'
AFTER=$("${CURL[@]}" "$BASE/todos" | jq length)
[ "$AFTER" -eq "$BEFORE" ] && echo "OK: lista voltou a $AFTER tarefas"

echo "Fluxo funcional completo em $BASE"
