# claude-switch

Trocar de conta no Claude Code CLI sem precisar de `/logout`, reabrir o navegador, autorizar de novo, etc. Você salva cada conta como um *profile* uma vez, e a partir daí alterna entre elas com um único comando.

## Por que existe

O fluxo nativo pra trocar de conta é:

1. Digitar `/logout` dentro do Claude.
2. Sair, rodar `claude` de novo.
3. Esperar abrir o navegador.
4. Fazer login na conta nova.
5. Autorizar o OAuth.
6. Repetir tudo se quiser voltar pra primeira conta.

Cansativo se você troca várias vezes por dia (ex.: conta pessoal vs. conta da empresa). O `claude-switch` faz isso em uma linha, sem browser, porque ele só rotaciona os *tokens já válidos* que o Claude Code guarda.

## Como funciona por baixo

O Claude Code armazena o estado da conta em dois lugares no macOS:

| O que | Onde |
|---|---|
| Tokens OAuth (access + refresh) | macOS Keychain — service `Claude Code-credentials`, account = `$USER` |
| Metadados da conta (`oauthAccount`, `userID`) | `~/.claude.json` |

Um **profile** é só um JSON em `~/.claude/profiles/<nome>.json` contendo um snapshot dos dois. O comando `use` restaura o snapshot — grava os tokens de volta no Keychain e substitui `oauthAccount` + `userID` em `~/.claude.json`. O Claude Code refresca o access token sozinho se estiver vencido, então o navegador não precisa abrir de novo.

Os tokens continuam protegidos pelo Keychain do macOS (a senha da sua conta libera o acesso), e os profiles ficam em arquivos locais que **você não deve versionar** — eles contêm refresh tokens válidos.

## Pré-requisitos

### Obrigatórios (sem isso o script não roda)

| Requisito | Como verificar | Como instalar / resolver |
|---|---|---|
| **macOS** | `uname -s` → `Darwin` | Não rola em Linux/Windows — depende de Keychain |
| **bash** | `command -v bash` | Já vem no macOS |
| **`security` CLI** | `command -v security` | Já vem no macOS (parte do `Security.framework`) |
| **`jq`** | `jq --version` | `brew install jq` |

### Necessários pra ter o que gerenciar

| Requisito | Como verificar | Como resolver |
|---|---|---|
| **Claude Code CLI instalado** | `claude --version` | `npm i -g @anthropic-ai/claude-code` |
| **`~/.claude.json` criado** | `ls ~/.claude.json` | Rode `claude` uma vez; o arquivo é criado na inicialização |
| **Pelo menos uma conta logada** | Conseguir abrir `claude` sem cair no login | Rode `claude` e complete o OAuth no navegador |

### Verificação automática

Use o comando `doctor` — checa tudo de uma vez e mostra exatamente o que falta:

```bash
claude-switch doctor
```

Saída esperada quando tudo está OK:

```
  [ok] macOS (26.5)
  [ok] bash
  [ok] security CLI
  [ok] jq (jq-1.7.1-apple)
  [ok] claude CLI (2.1.142)
  [ok] /Users/marlos/.claude.json
  [ok] credenciais no Keychain (conta ativa: voce@exemplo.com)
  [ok] profiles salvos: 2 (em /Users/marlos/.claude/profiles)

tudo ok pra rodar.
```

Se aparecer `[falta]` em algum item obrigatório, o `doctor` sai com código de saída `1`. Itens marcados `[aviso]` não bloqueiam o script em si, mas indicam coisas que você vai precisar antes de usar `save` (ex.: não estar logado em nenhuma conta).

O `install.sh` roda essas mesmas verificações antes de instalar.

## Instalação

```bash
cd ~/Developer/claude-switch
./install.sh                  # auto-detecta o shell
./install.sh --shell=fish     # força fish (recomendado pra quem usa fish)
./install.sh --shell=zsh      # força zsh
./install.sh --shell=bash     # força bash
```

> **Importante para usuários de fish**: o macOS guarda como "shell de login" o `/bin/bash` por padrão, mesmo se você abre o terminal direto no fish. Auto-detecção pode errar nesse caso — use `--shell=fish` explicitamente.

O instalador:

1. Roda todas as verificações de pré-requisitos (mesma coisa que `claude-switch doctor`).
2. Copia o script para `~/.claude/bin/claude-switch` (deixa executável).
3. Cria `~/.claude/profiles/` se não existir.
4. Adiciona `~/.claude/bin` ao seu `PATH`:
   - **fish**: `fish_add_path -U ~/.claude/bin` (universal, persiste entre sessões).
   - **zsh**: adiciona uma linha ao `~/.zshrc` (idempotente — só adiciona se não existir).
   - **bash**: adiciona ao `~/.bash_profile` (se existir) ou `~/.bashrc`.
5. Mostra como recarregar o `PATH`.

Se preferir instalar à mão, é só copiar `claude-switch` pra qualquer lugar no `PATH` e dar `chmod +x`.

## Uso

### Primeira vez (registro de cada conta)

Esse passo só acontece uma vez por conta. Depois você nunca mais vê o navegador (até o refresh token expirar, o que demora bastante).

```bash
# 1) Você já está logado em uma conta (ex.: pessoal). Salve como profile:
claude-switch save pessoal

# 2) Saia da conta atual e logue na conta nova:
claude-switch logout
claude               # abre o navegador, faz login na outra conta

# 3) Salve a segunda conta como profile:
claude-switch save trabalho
```

### Uso recorrente (o que você vai fazer de fato)

```bash
claude-switch use pessoal      # ativa a conta pessoal
claude-switch use trabalho     # ativa a conta de trabalho
claude-switch list             # lista profiles ('*' marca o ativo)
claude-switch current          # mostra qual conta está logada agora
```

Depois de `use`, é só rodar `claude` normalmente — já vai estar na conta certa.

### Outros comandos

```bash
claude-switch logout           # remove os tokens do Keychain (profiles ficam)
claude-switch rm <nome>        # apaga um profile salvo
claude-switch help             # mostra a ajuda
```

## Referência rápida dos comandos

| Comando | O que faz |
|---|---|
| `claude-switch save <nome>` | Salva a conta atualmente logada como profile `<nome>` |
| `claude-switch use <nome>` | Ativa o profile `<nome>` (sem browser) |
| `claude-switch list` (ou `ls`) | Lista todos os profiles e o e-mail de cada |
| `claude-switch current` | Mostra qual conta está ativa agora |
| `claude-switch logout` | Limpa os tokens do Keychain (não apaga profiles) |
| `claude-switch rm <nome>` | Apaga o profile `<nome>` do disco |
| `claude-switch doctor` | Verifica pré-requisitos e estado do ambiente |
| `claude-switch help` | Mostra a ajuda |

## Cenários comuns

**Trocar de conta no meio do dia:**
```bash
claude-switch use trabalho
claude
```

**Atualizar um profile (porque o token foi renovado e você quer salvar o estado novo):**
```bash
# basta dar save de novo com o mesmo nome — sobrescreve.
claude-switch save trabalho
```

**Logar em uma terceira conta:**
```bash
claude-switch logout
claude              # navegador abre, loga na conta nova
claude-switch save cliente-x
```

**Ver se você está na conta certa antes de mandar uma pergunta cara:**
```bash
claude-switch current
```

## Cuidados

- **Não versione `~/.claude/profiles/`**. Os arquivos ali dentro contêm `refreshToken` válidos — quem tiver o arquivo loga como você. O `.gitignore` deste repositório já bloqueia, mas se você mover os profiles pra outro lugar, lembre disso.
- **Backup**: se você quiser passar uma conta pra outra máquina sua, copie o JSON do profile via canal seguro (AirDrop, scp). Não cole em chat/email.
- **Refresh token expira**: eventualmente o refresh token vira (semanas/meses). Quando isso acontecer, `claude-switch use <nome>` ainda restaura o estado, mas o próximo `claude` vai pedir login pelo navegador. Aí você roda `claude-switch save <nome>` de novo pra atualizar o profile.
- **Conta atual não salva**: se você der `use` em um profile sem ter salvado a conta atualmente ativa, o script avisa antes — você pode cancelar com Ctrl-C e dar `save` primeiro.

## Desinstalação

```bash
cd ~/Developer/claude-switch
./uninstall.sh
```

Isso remove só o binário em `~/.claude/bin/claude-switch`. Os profiles em `~/.claude/profiles/` ficam (apague à mão se quiser). A linha de `PATH` adicionada ao seu shell rc também fica — remova manualmente se quiser.

## Estrutura do projeto

```
~/Developer/claude-switch/
├── claude-switch          # o script em si
├── README.md              # este documento
├── install.sh             # instalador
├── uninstall.sh           # desinstalador
└── .gitignore             # garante que profiles não vazem se você versionar
```

## Troubleshooting

**`jq não encontrado`** → `brew install jq`.

**`sem credenciais ativas no Keychain`** ao dar `save` → você não está logado. Rode `claude` e faça login primeiro.

**`~/.claude.json não encontrado`** → você nunca rodou `claude` nessa máquina. Rode uma vez pra ele inicializar.

**`use` ativou o profile mas o Claude continua na conta antiga** → certifique-se de que o processo `claude` não estava aberto (ele só relê as credenciais ao iniciar). Saia e rode de novo.

**Quero rodar comandos diferentes em sessões diferentes ao mesmo tempo (sem mexer no estado global)** → não dá com este script (o Claude Code lê de um único lugar). Pra esse caso, melhor usar perfis separados de macOS ou containers.
