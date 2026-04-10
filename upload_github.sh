#!/usr/bin/env bash
set -euo pipefail

if [[ ${1:-} == "" ]]; then
  echo "Uso: ./upload_github.sh \"mensagem\""
  exit 1
fi

MSG="$1"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Erro: este script precisa ser executado dentro de um repo git."
  exit 1
fi

REPO_URL="https://github.com/wiredevelop/studio59.git"
TOKEN="${GITHUB_TOKEN:-}"
TOKEN_FILE="docs/token git"

if [[ -f "$TOKEN_FILE" ]]; then
  if [[ -z "$TOKEN" ]]; then
    TOKEN=$(awk -F'token:' 'tolower($0) ~ /token:/ {gsub(/^[ \t]+|[ \t]+$/,"",$2); print $2; exit}' "$TOKEN_FILE")
  fi
  REPO_LINE=$(awk -F'repo:' 'tolower($0) ~ /repo:/ {gsub(/^[ \t]+|[ \t]+$/,"",$2); print $2; exit}' "$TOKEN_FILE" || true)
  if [[ -n "${REPO_LINE:-}" ]]; then
    REPO_URL="$REPO_LINE"
  fi
fi

if [[ -z "$TOKEN" ]]; then
  echo "Erro: GITHUB_TOKEN nao definido e token nao encontrado em 'docs/token git'."
  echo "Defina: export GITHUB_TOKEN=SEU_TOKEN"
  exit 1
fi

# Evita prompts interativos
export GIT_TERMINAL_PROMPT=0

# Garante config minima para commit
if ! git config user.name >/dev/null; then
  git config user.name "backup-bckmobile"
fi
if ! git config user.email >/dev/null; then
  git config user.email "backup@local"
fi

PREV_REF=$(git symbolic-ref --short -q HEAD || git rev-parse --short HEAD)
CURRENT_BRANCH=$(git symbolic-ref --short -q HEAD || echo "HEAD")

# Cria branch bckmobile sem histórico (snapshot) para evitar bloqueios por segredos antigos
if git rev-parse --verify --quiet bckmobile >/dev/null; then
  if [[ "$CURRENT_BRANCH" == "bckmobile" ]]; then
    git checkout --detach >/dev/null 2>&1 || true
  fi
  git branch -D bckmobile
fi
git checkout --orphan bckmobile
git rm -rf --cached . >/dev/null 2>&1 || true

# Evita subir token por engano (Push Protection bloqueia)
if [[ -f "$TOKEN_FILE" ]]; then
  if ! rg -n --fixed-strings --quiet "$TOKEN_FILE" .gitignore 2>/dev/null; then
    printf "\n# Segredo local\n%s\n" "$TOKEN_FILE" >> .gitignore
  fi
  if git ls-files --error-unmatch "$TOKEN_FILE" >/dev/null 2>&1; then
    git rm --cached "$TOKEN_FILE"
  fi
fi

# Adiciona tudo (inclui deletes)
git add -A

if ! git diff --cached --quiet; then
  git commit -m "$MSG"
fi

# Push forçado para bckmobile
PUSH_URL="https://${TOKEN}@github.com/$(echo "$REPO_URL" | sed -E 's#https://github.com/##; s#^git@github.com:##; s#\.git$##').git"

git push --force "$PUSH_URL" bckmobile

# Volta para o ref anterior
if [[ "$PREV_REF" == "HEAD" ]]; then
  # caso raro; tenta voltar com checkout -
  git checkout - >/dev/null 2>&1 || true
else
  git checkout "$PREV_REF"
fi

echo "Upload concluido para a branch bckmobile."
