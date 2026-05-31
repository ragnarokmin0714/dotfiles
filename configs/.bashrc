# =============================================================================
# configs/.bashrc — Bash Shell Configuration Template
# =============================================================================
# This file is deployed to ~/.bashrc by system/bashrc.sh.
# It sets up a productive shell environment with:
#   - Useful aliases
#   - nvm (Node Version Manager) integration
#   - pnpm path
#   - Git branch in prompt
#   - Colored output
# =============================================================================

# If not running interactively, do nothing
case $- in
  *i*) ;;
    *) return ;;
esac

# --- History settings ---
HISTCONTROL=ignoreboth           # Ignore duplicate lines and lines starting with space
HISTSIZE=10000                   # Number of commands to keep in memory
HISTFILESIZE=20000               # Number of commands to keep in the history file
shopt -s histappend              # Append to history file, don't overwrite

# --- Shell options ---
shopt -s checkwinsize            # Update LINES/COLUMNS after each command
shopt -s globstar                # Enable ** glob pattern
shopt -s cdspell                 # Auto-correct minor typos in cd command

# --- Prompt with Git branch ---
_git_branch() {
  local branch
  branch="$(git symbolic-ref --short HEAD 2>/dev/null)" && echo " ($branch)"
}
export PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[33m\]$(_git_branch)\[\033[00m\]\$ '

# --- Color support ---
export CLICOLOR=1
export LS_COLORS='di=1;34:ln=1;36:so=1;35:pi=33:ex=1;32:bd=1;33:cd=1;33:su=1;41:sg=1;43:tw=1;42:ow=1;42:'
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias diff='diff --color=auto'

# --- Navigation aliases ---
alias ..='cd ..'
alias ...='cd ../..'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# --- Git aliases ---
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph --decorate'

# --- Docker aliases ---
alias dps='docker ps'
alias dpa='docker ps -a'
alias dlog='docker logs -f'
alias dex='docker exec -it'

# --- System aliases ---
alias ports='ss -tulnp'          # Show open ports
alias myip='curl -s ifconfig.me' # Show public IP

# --- nvm (Node Version Manager) ---
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# --- pnpm ---
export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac

# --- Go ---
export PATH="$PATH:/usr/local/go/bin"
export GOPATH="$HOME/go"
export PATH="$PATH:$GOPATH/bin"

# --- Local bin ---
export PATH="$HOME/.local/bin:$PATH"

# --- Shell alias modules (~/.alias/) ---
# Sources .bash_env (STYLE/git_prompt/build_ps1), .bash_git, .bash_functions
[ -f ~/.alias/.bash_aliases ] && source ~/.alias/.bash_aliases

# Rebuild the custom PS1 before each prompt
PROMPT_COMMAND=build_ps1
