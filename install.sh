#!/usr/bin/env bash
# Instalador idempotente do claude-switch.
# Copia o script pra ~/.claude/bin e tenta colocá-lo no PATH do seu shell.
#
# Uso:
#   ./install.sh                  # tenta auto-detectar o shell
#   ./install.sh --shell=fish     # força fish (recomendado se o login shell é outro)
#   ./install.sh --shell=zsh      # força zsh
#   ./install.sh --shell=bash     # força bash

set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="${SRC_DIR}/claude-switch"
BIN_DIR="${HOME}/.claude/bin"
DEST="${BIN_DIR}/claude-switch"
PROFILES_DIR="${HOME}/.claude/profiles"
LINUX_CREDENTIALS_JSON="${HOME}/.claude/.credentials.json"

# Parse flags
FORCED_SHELL=""
for arg in "$@"; do
  case "${arg}" in
    --shell=*) FORCED_SHELL="${arg#--shell=}" ;;
    -h|--help)
      sed -n '2,/^set -euo/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "flag desconhecida: ${arg}" >&2; exit 1 ;;
  esac
done

info()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
die()   { printf '\033[1;31merro:\033[0m %s\n' "$*" >&2; exit 1; }

[[ -f "${SRC}" ]] || die "não encontrei ${SRC} — rode esse install.sh de dentro de ~/Developer/claude-switch"

# 1) pré-requisitos
info "verificando pré-requisitos"

# 1.1) sistema operacional
OS_NAME="$(uname -s)"
case "${OS_NAME}" in
  Darwin) printf '  [ok] macOS\n' ;;
  Linux) printf '  [ok] Linux\n' ;;
  *) die "este script só funciona no macOS ou Linux (detectei: ${OS_NAME})" ;;
esac

# 1.2) bash
if ! command -v bash >/dev/null; then
  die "bash não encontrado no PATH"
fi
printf '  [ok] bash (%s)\n' "$(bash --version | head -1)"

# 1.3) security CLI (sempre vem no macOS, mas validamos)
if [[ "${OS_NAME}" == "Darwin" ]]; then
  if ! command -v security >/dev/null; then
    die "'security' CLI ausente — instalação do macOS quebrada?"
  fi
  printf '  [ok] security CLI\n'
fi

# 1.4) jq (obrigatório em runtime — sem ele o script não roda)
if ! command -v jq >/dev/null; then
  warn "jq não está instalado — instale antes de usar: brew install jq"
  JQ_OK=""
else
  printf '  [ok] jq (%s)\n' "$(jq --version)"
  JQ_OK="1"
fi

# 1.5) Claude Code CLI (precisa ter rodado pelo menos uma vez)
if ! command -v claude >/dev/null; then
  warn "comando 'claude' não está no PATH — instale o Claude Code antes (npm i -g @anthropic-ai/claude-code)"
else
  printf '  [ok] claude CLI (%s)\n' "$(claude --version 2>/dev/null | head -1 || echo 'versão desconhecida')"
fi

# 1.6) ~/.claude.json (criado no primeiro run do claude)
if [[ ! -f "${HOME}/.claude.json" ]]; then
  warn "~/.claude.json ainda não existe — rode 'claude' uma vez pra inicializar antes de 'save'"
else
  printf '  [ok] ~/.claude.json existe\n'
fi

# 1.7) credenciais no Keychain (necessárias pra 'save' inicial)
if [[ "${OS_NAME}" == "Darwin" ]]; then
  if ! security find-generic-password -s "Claude Code-credentials" -a "${USER}" >/dev/null 2>&1; then
    warn "sem credenciais ativas no Keychain — faça login com 'claude' antes do primeiro 'save'"
  else
    printf '  [ok] credenciais no Keychain\n'
  fi
elif [[ ! -f "${LINUX_CREDENTIALS_JSON}" ]]; then
  warn "sem credenciais ativas em ${LINUX_CREDENTIALS_JSON} — faça login com 'claude' antes do primeiro 'save'"
else
  printf '  [ok] credenciais em %s\n' "${LINUX_CREDENTIALS_JSON}"
fi


# 2) copia o binário
info "copiando script para ${DEST}"
mkdir -p "${BIN_DIR}" "${PROFILES_DIR}"
cp "${SRC}" "${DEST}"
chmod +x "${DEST}"

# 3) PATH: detecta o shell e adiciona ~/.claude/bin se ainda não estiver
add_to_rc() {
  local rc="$1"
  local line='export PATH="$HOME/.claude/bin:$PATH"'
  [[ -f "${rc}" ]] || touch "${rc}"
  if grep -Fq '.claude/bin' "${rc}"; then
    info "${rc} já referencia ~/.claude/bin — nada a fazer"
  else
    printf '\n# adicionado por claude-switch install.sh\n%s\n' "${line}" >> "${rc}"
    info "adicionei ~/.claude/bin ao ${rc}"
  fi
}

# Determina o shell:
#   1) --shell=<x> manda (mais confiável; muitos usuários rodam fish a partir de bash/zsh).
#   2) Senão, tenta $SHELL (reflete a sessão interativa).
#   3) Senão, dscl (shell de login no nível do sistema, macOS).
if [[ -n "${FORCED_SHELL}" ]]; then
  current_shell="${FORCED_SHELL}"
  info "shell informado via --shell: ${current_shell}"
else
  user_shell_path=""
  if [[ "${OS_NAME}" == "Darwin" ]]; then
    user_shell_path="$(dscl . -read "/Users/${USER}" UserShell 2>/dev/null | awk '{print $2}')"
  fi
  current_shell="$(basename "${SHELL:-${user_shell_path:-bash}}")"
  info "shell detectado: ${current_shell} (se estiver errado, rode novamente com --shell=fish|zsh|bash)"
fi
case "${current_shell}" in
  fish)
    if command -v fish >/dev/null; then
      info "configurando PATH no fish via fish_add_path"
      # -U: universal, persistente entre sessões.
      fish -c "fish_add_path -U ${BIN_DIR}" || warn "não consegui rodar fish_add_path — adicione manualmente"
    else
      warn "SHELL aponta pra fish, mas fish não foi encontrado no PATH"
    fi
    ;;
  zsh)
    add_to_rc "${HOME}/.zshrc"
    ;;
  bash)
    if [[ -f "${HOME}/.bash_profile" ]]; then
      add_to_rc "${HOME}/.bash_profile"
    else
      add_to_rc "${HOME}/.bashrc"
    fi
    ;;
  *)
    warn "shell '${current_shell}' não reconhecido — adicione ~/.claude/bin ao seu PATH manualmente"
    ;;
esac

# 4) sanity check
info "instalado:"
"${DEST}" help | head -3 || true

cat <<EOF

pronto. abre um terminal novo (ou roda 'exec ${current_shell}') pra carregar o PATH atualizado.

próximos passos:
  claude-switch save <nome>     # salva a conta logada atualmente
  claude-switch list            # lista profiles
  claude-switch use <nome>      # troca pra um profile

doc completa: ${SRC_DIR}/claude-switch.md
EOF

if [[ "${OS_NAME}" == "Linux" && -t 0 && -t 1 && "${CLAUDE_SWITCH_SKIP_SHELL_RELOAD:-}" != "1" ]]; then
  info "recarregando shell para disponibilizar claude-switch neste terminal"
  exec "${current_shell}"
fi
