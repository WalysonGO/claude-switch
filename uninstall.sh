#!/usr/bin/env bash
# Remove o binário claude-switch.
# Não apaga profiles em ~/.claude/profiles — faça isso manualmente se quiser.
# Não remove a linha de PATH que install.sh adicionou ao seu rc — remova manualmente.

set -euo pipefail

DEST="${HOME}/.claude/bin/claude-switch"

info() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }

if [[ -f "${DEST}" ]]; then
  rm "${DEST}"
  info "removi ${DEST}"
else
  warn "${DEST} não existe — nada a remover"
fi

cat <<EOF

obs:
  - profiles em ~/.claude/profiles/ NÃO foram apagados (apague à mão se quiser)
  - a linha de PATH no seu shell rc NÃO foi removida (edite à mão se quiser)
EOF
