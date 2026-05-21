# claude-switch

Trocar de conta no Claude Code CLI sem precisar de `/logout`, reabrir o navegador, autorizar de novo, etc. Você salva cada conta como um *profile* uma vez, e depois alterna entre elas com um comando.

## Por que existe

O fluxo nativo pra trocar de conta é:

1. Digitar `/logout` dentro do Claude.
2. Sair, rodar `claude` de novo.
3. Esperar abrir o navegador.
4. Fazer login na conta nova.
5. Autorizar o OAuth.
6. Repetir tudo se quiser voltar pra primeira conta.

O `claude-switch` evita esse ritual porque só rotaciona tokens já válidos que o Claude Code guarda localmente.

## Como funciona por baixo

O Claude Code armazena estado de conta em credenciais OAuth + metadados globais:

| Sistema | Tokens OAuth | Metadados da conta |
|---|---|---|
| macOS | Keychain — service `Claude Code-credentials`, account = `$USER` | `~/.claude.json` (`oauthAccount`, `userID`) |
| Linux | `~/.claude/.credentials.json` (`claudeAiOauth`) | `~/.claude.json` (`oauthAccount`, `userID`) |

Um **profile** é um JSON em `~/.claude/profiles/<nome>.json` com snapshot dos tokens e metadados. O comando `use` restaura esse snapshot no backend do sistema atual e atualiza `~/.claude.json`.

No Linux, `claude-switch` preserva campos extras existentes em `~/.claude/.credentials.json`, como `organizationUuid`, e troca apenas `claudeAiOauth`.

## Pré-requisitos

### Obrigatórios

| Requisito | Como verificar | Como resolver |
|---|---|---|
| **macOS ou Linux** | `uname -s` → `Darwin` ou `Linux` | Windows não é suportado |
| **bash** | `command -v bash` | macOS já vem com bash; Linux via gerenciador da distro |
| **jq** | `jq --version` | macOS: `brew install jq`; Linux: `apt install jq`, `dnf install jq`, etc. |
| **macOS: `security` CLI** | `command -v security` | Já vem no macOS |

### Necessários pra ter o que gerenciar

| Requisito | Como verificar | Como resolver |
|---|---|---|
| **Claude Code CLI instalado** | `claude --version` | `npm i -g @anthropic-ai/claude-code` |
| **`~/.claude.json` criado** | `ls ~/.claude.json` | Rode `claude` uma vez |
| **Pelo menos uma conta logada** | Abrir `claude` sem cair no login | Rode `claude` e complete OAuth no navegador |

## Verificação automática

```bash
claude-switch doctor
```

Exemplo macOS:

```text
  [ok] macOS (26.5) — backend: Keychain
  [ok] bash
  [ok] security CLI
  [ok] jq (jq-1.7.1)
  [ok] claude CLI (2.1.142)
  [ok] /Users/voce/.claude.json
  [ok] credenciais ativas em Keychain (conta ativa: voce@exemplo.com)
  [ok] profiles salvos: 2 (em /Users/voce/.claude/profiles)

tudo ok pra rodar.
```

Exemplo Linux:

```text
  [ok] Linux — backend: /home/voce/.claude/.credentials.json
  [ok] bash
  [ok] jq (jq-1.7.1)
  [ok] claude CLI (2.1.142)
  [ok] /home/voce/.claude.json
  [ok] /home/voce/.claude/.credentials.json
  [ok] credenciais ativas em /home/voce/.claude/.credentials.json (conta ativa: voce@exemplo.com)
  [ok] profiles salvos: 2 (em /home/voce/.claude/profiles)

tudo ok pra rodar.
```

Itens `[falta]` fazem `doctor` sair com código `1`. Itens `[aviso]` não bloqueiam instalação, mas indicam passos necessários antes de `save`.

## Instalação

```bash
cd ~/Developer/claude-switch
./install.sh                  # auto-detecta o shell
./install.sh --shell=fish     # força fish
./install.sh --shell=zsh      # força zsh
./install.sh --shell=bash     # força bash
```

O instalador:

1. Verifica sistema, `bash`, `jq`, Claude Code e backend de credenciais.
2. Copia o script para `~/.claude/bin/claude-switch`.
3. Cria `~/.claude/profiles/` se não existir.
4. Adiciona `~/.claude/bin` ao `PATH` no `fish`, `zsh` ou `bash`.
5. No Linux interativo, abre um novo shell já com `PATH` recarregado. Em ambientes não interativos, mostra o comando de `source`/`exec` necessário.

Instalação manual: copie `claude-switch` pra qualquer diretório no `PATH` e rode `chmod +x`.

## Uso

### Primeira vez

```bash
# 1) Você já está logado em uma conta (ex.: pessoal).
claude-switch save pessoal

# 2) Saia da conta atual e logue na conta nova.
claude-switch logout
claude

# 3) Salve a segunda conta.
claude-switch save trabalho
```

### Uso recorrente

```bash
claude-switch use pessoal
claude-switch use trabalho
claude-switch list
claude-switch current
```

Depois de `use`, rode `claude` normalmente. Ele inicia com a conta restaurada.

## Referência rápida

| Comando | O que faz |
|---|---|
| `claude-switch save <nome>` | Salva a conta atualmente logada como profile |
| `claude-switch use <nome>` | Ativa o profile sem browser |
| `claude-switch list` ou `ls` | Lista profiles e marca o ativo com `*` |
| `claude-switch current` | Mostra conta ativa |
| `claude-switch logout` | Remove tokens do backend atual sem apagar profiles |
| `claude-switch rm <nome>` | Apaga profile salvo |
| `claude-switch doctor` | Verifica ambiente |
| `claude-switch help` | Mostra ajuda |

## Cuidados de segurança

- **Não versione `~/.claude/profiles/`**. Profiles contêm `refreshToken` válido.
- **No Linux, proteja `~/.claude/.credentials.json`**. Esse arquivo também contém token válido.
- **Use canais seguros para backup**. Não cole profiles em chat, issue, email ou gist.
- **Refresh token expira**. Se o Claude pedir login após `use`, faça login e rode `claude-switch save <nome>` de novo.
- **Processos abertos não relêem estado**. Feche e reabra `claude` depois de trocar profile.

## Testes manuais

Fluxo AAA sugerido para validar sem usar tokens reais:

1. **Arrange**: crie `HOME` temporário com `.claude.json`, `.claude/.credentials.json` e profiles fake.
2. **Act**: rode `HOME=/tmp/claude-switch-test ./claude-switch save teste`, `list`, `use teste`, `current`, `logout`.
3. **Assert**: valide JSON com `jq`, saída esperada, preservação de `organizationUuid`, permissões `0600` e exit code.

## Desinstalação

```bash
cd ~/Developer/claude-switch
./uninstall.sh
```

Remove só `~/.claude/bin/claude-switch`. Profiles em `~/.claude/profiles/` e linha de `PATH` ficam para remoção manual.

## Estrutura do projeto

```text
claude-switch/
├── claude-switch
├── install.sh
├── uninstall.sh
├── README.md
├── QUESTIONS.md
└── .gitignore
```

## Troubleshooting

**`jq não encontrado`** → instale `jq` pelo Homebrew ou gerenciador da distro.

**`sem credenciais ativas` ao dar `save`** → rode `claude` e faça login primeiro.

**`~/.claude.json não encontrado`** → rode `claude` uma vez.

**Linux: `~/.claude/.credentials.json` não existe** → rode `claude` e complete OAuth no navegador.

**`use` ativou profile mas Claude continua na conta antiga** → encerre processo `claude` aberto e rode de novo.

**Quero contas diferentes em sessões simultâneas** → este script muda estado global do Claude Code; use usuários/sandboxes separados para paralelismo real.
