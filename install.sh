#!/usr/bin/env bash
# Instalador idempotente do claude-switch.
# Copia o script pra ~/.claude/bin e tenta colocá-lo no PATH do seu shell.
#
# Uso:
#   ./install.sh                  # tenta auto-detectar o shell
#   ./install.sh --shell=fish     # força fish
#   ./install.sh --shell=zsh      # força zsh
#   ./install.sh --shell=bash     # força bash

set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="${SRC_DIR}/claude-switch"
BIN_DIR="${HOME}/.claude/bin"
DEST="${BIN_DIR}/claude-switch"
PROFILES_DIR="${HOME}/.claude/profiles"
LINUX_CREDENTIALS_JSON="${HOME}/.claude/.credentials.json"

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

claude_version() {
  if command -v timeout >/dev/null; then
    timeout 3 claude --version 2>/dev/null | head -1 || echo 'versão desconhecida'
  else
    claude --version 2>/dev/null | head -1 || echo 'versão desconhecida'
  fi
}

[[ -f "${SRC}" ]] || die "não encontrei ${SRC} — rode esse install.sh de dentro do repositório claude-switch"

info "verificando pré-requisitos"

OS_NAME="$(uname -s)"
case "${OS_NAME}" in
  Darwin)
    printf '  [ok] macOS\n'
    if ! command -v security >/dev/null; then
      die "'security' CLI ausente — instalação do macOS quebrada?"
    fi
    printf '  [ok] security CLI\n'
    ;;
  Linux)
    printf '  [ok] Linux\n'
    if [[ -f "${LINUX_CREDENTIALS_JSON}" ]]; then
      printf '  [ok] %s existe\n' "${LINUX_CREDENTIALS_JSON}"
    else
      warn "${LINUX_CREDENTIALS_JSON} ainda não existe — rode 'claude' e faça login antes de 'save'"
    fi
    ;;
  *)
    die "sistema não suportado: ${OS_NAME} (suportados: macOS/Darwin e Linux)"
    ;;
esac

if ! command -v bash >/dev/null; then
  die "bash não encontrado no PATH"
fi
printf '  [ok] bash (%s)\n' "$(bash --version | head -1)"

if ! command -v jq >/dev/null; then
  warn "jq não está instalado — instale antes de usar (macOS: brew install jq; Linux: gerenciador de pacotes da distro)"
else
  printf '  [ok] jq (%s)\n' "$(jq --version)"
fi

if ! command -v claude >/dev/null; then
  warn "comando 'claude' não está no PATH — instale o Claude Code antes (npm i -g @anthropic-ai/claude-code)"
else
  printf '  [ok] claude CLI (%s)\n' "$(claude_version)"
fi

if [[ ! -f "${HOME}/.claude.json" ]]; then
  warn "~/.claude.json ainda não existe — rode 'claude' uma vez pra inicializar antes de 'save'"
else
  printf '  [ok] ~/.claude.json existe\n'
fi

if [[ "${OS_NAME}" == "Darwin" ]]; then
  if ! security find-generic-password -s "Claude Code-credentials" -a "${USER}" >/dev/null 2>&1; then
    warn "sem credenciais ativas no Keychain — faça login com 'claude' antes do primeiro 'save'"
  else
    printf '  [ok] credenciais no Keychain\n'
  fi
fi

info "copiando script para ${DEST}"
mkdir -p "${BIN_DIR}" "${PROFILES_DIR}"
cp "${SRC}" "${DEST}"
chmod +x "${DEST}"

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

if [[ -n "${FORCED_SHELL}" ]]; then
  current_shell="${FORCED_SHELL}"
  info "shell informado via --shell: ${current_shell}"
else
  current_shell="$(basename "${SHELL:-bash}")"
  info "shell detectado: ${current_shell} (se estiver errado, rode novamente com --shell=fish|zsh|bash)"
fi

case "${current_shell}" in
  fish)
    if command -v fish >/dev/null; then
      info "configurando PATH no fish via fish_add_path"
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

info "instalado:"
"${DEST}" help | head -3 || true

reload_cmd="exec ${current_shell}"
case "${current_shell}" in
  zsh) reload_cmd="source ${HOME}/.zshrc" ;;
  bash)
    if [[ -f "${HOME}/.bash_profile" ]]; then
      reload_cmd="source ${HOME}/.bash_profile"
    else
      reload_cmd="source ${HOME}/.bashrc"
    fi
    ;;
  fish) reload_cmd="exec fish" ;;
esac

cat <<EOF

pronto. comando instalado em ${DEST}.

próximos passos:
  claude-switch save <nome>     # salva a conta logada atualmente
  claude-switch list            # lista profiles
  claude-switch use <nome>      # troca pra um profile

doc completa: ${SRC_DIR}/README.md
EOF

if [[ "${OS_NAME}" == "Linux" && -t 0 && -t 1 && "${CLAUDE_SWITCH_SKIP_SHELL_RELOAD:-}" != "1" ]]; then
  case "${current_shell}" in
    zsh|bash|fish)
      info "abrindo um novo ${current_shell} com PATH recarregado (saia com 'exit' se quiser voltar)"
      exec "${current_shell}"
      ;;
    *)
      warn "não consegui recarregar shell automaticamente — rode: ${reload_cmd}"
      ;;
  esac
else
  info "para carregar o PATH neste terminal, rode: ${reload_cmd}"
fi
