# ==========================================
# PATH
# ==========================================

export PATH="$HOME/.local/bin:$PATH"

# pnpm global binaries
export PNPM_HOME="$HOME/Library/pnpm"
export PATH="$PNPM_HOME/bin:$PATH"

# ==========================================
# mise
# ==========================================

eval "$(mise activate zsh)"

# ==========================================
# Zsh Completion
# ==========================================

autoload -Uz compinit
compinit

# ==========================================
# fzf
# ==========================================

source <(fzf --zsh)

# ==========================================
# zoxide
# ==========================================

eval "$(zoxide init zsh)"

# ==========================================
# Starship
# ==========================================

eval "$(starship init zsh)"

# ==========================================
# Zsh Plugins
# ==========================================

# Command history suggestions
source "$(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh"

# Syntax highlighting (load last)
source "$(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"