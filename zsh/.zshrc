
ZSH_THEME="robbyrussell"
#ZSH_THEME="agnoster"

## Options section
setopt correct

export ZSH="${HOME}/.oh-my-zsh"
export PATH="$PATH:/usr/local/go/bin"
export GOPATH="$HOME/go"
export PATH="$PATH:$GOPATH/bin"

# Color of man pages
export LESS_TERMCAP_mb=$'\e[01;32m'
export LESS_TERMCAP_md=$'\e[01;32m'
export LESS_TERMCAP_me=$'\e[0m'
export LESS_TERMCAP_se=$'\e[0m'
export LESS_TERMCAP_so=$'\e[01;47;34m'
export LESS_TERMCAP_ue=$'\e[0m'
export LESS_TERMCAP_us=$'\e[01;36m'
export LESS=-r

# Aliases
alias vi="nvim"
alias vim="nvim"
alias ls="ls -a"
alias df='df -h'
alias top='htop'
export VISUAL='nvim'
export EDITOR='nvim'
export PAGER='less'

ENABLE_CORRECTION="true"
DISABLE_AUTO_UPDATE="true"

plugins=(git)
source $ZSH/oh-my-zsh.sh
