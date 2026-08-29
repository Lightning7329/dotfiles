# prompt string
__bash_prompt() {
    local RESET_COLOR='\[\e[0m\]'
    local RED='\[\e[0;31m\]'
    local GREEN='\[\e[0;32m\]'
    local MAGENTA='\[\e[0;35m\]'
    local CYAAN='\[\e[0;36m\]'
    local GRAY='\[\e[2;37m\]'

    local gitbranch='`\
    branchName=$(git --no-optional-locks symbolic-ref --short HEAD 2>/dev/null || git --no-optional-locks rev-parse --short HEAD 2>/dev/null)
    if [ -n "$branchName" ] ; then
        case "$branchName" in
            "main" | "master" )
                branchColor="'$RED'";;
            "develop" )
                branchColor="'$CYAAN'";;
            * )
                branchColor="'$GRAY'";;
        esac
        branchName="($branchName) "
    fi
    echo -n "$branchColor$branchName"`'

    # VENV_COLOR=$MAGENTA
    # VENV_NAME=${VIRTUAL_ENV##*/}
    # if [ -n "$VENV_NAME" ] ; then
    #     VENV_NAME="($VENV_NAME) "
    # fi
    local dir='`
    if [ -n "$WORKSPACE_FOLDER" ] && [[ $PWD == $WORKSPACE_FOLDER* ]]; then
        workspaceBase=${WORKSPACE_FOLDER%/*}
        echo -n "${PWD#$workspaceBase/}"
    else
        echo -n "\w"
    fi`'

    PS1="$gitbranch$GREEN$dir$RESET_COLOR\$ "
    unset -f __bash_prompt
}
__bash_prompt

# aliases
alias hisgrep='history | grep'
alias gs='git status'
alias gss='git status -sb'
alias gg='git graph -10'
alias gb='git branch'

# functions
cc() {
    echo -n $1 | wc -c
}

cb() {
    branchName=$(git branch 2>/dev/null | grep -E '^\* ' | sed 's/^\* //')
    echo $branchName
}

pathconv() {
    echo $1 | sed 's/^C:/c/' | tr '\\' '/'
}
