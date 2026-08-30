HISTFILE=~/.histfile
HISTSIZE=10000
SAVEHIST=100000
setopt hist_ignore_dups     # 直前と同じコマンドを追加しない
setopt share_history        # 他のZSHと履歴を共有
setopt inc_append_history   # 即座に履歴に追記
bindkey '^P' history-beginning-search-backward
bindkey '^N' history-beginning-search-forward

# edit command line
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^[e' edit-command-line # <Esc> + E

# push line
bindkey '^[s' push-line # <Esc> + S

# completion
fpath=(~/.zsh/completion $fpath)
autoload -Uz compinit
compinit

# functions
function cc() {
    echo -n $1 | wc -c
}

# Dev Container ではユーザー名も表示する
typeset -g __user_prefix=''
if [[ -f /.dockerenv ]]; then
    __user_prefix='%n:'
fi

function precmd() {
    local branchName=$(git --no-optional-locks symbolic-ref --short HEAD 2>/dev/null || git --no-optional-locks rev-parse --short HEAD 2>/dev/null)
    if [ -n "$branchName" ]; then
        branchName="
($branchName)"
    fi

    if [[ -n "$WORKSPACE_FOLDER" && $PWD == $WORKSPACE_FOLDER* ]]; then
        workspaceBase=${WORKSPACE_FOLDER%/*}
        dir="${PWD#$workspaceBase/}"
    else
        dir="%~"
    fi

    PROMPT="%F{240}$VIRTUAL_ENV_PROMPT$branchName%f"'
%F{012}'$__user_prefix$dir'%f%# '
}

# aliases
alias printpath='echo $PATH | tr : \\n'
alias hisgrep='history | grep'
alias gs='git status'
alias gss='git status -sb'
alias gg='git graph -10'
alias gb='git branch'
alias dps='docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}"'
