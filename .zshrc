
export ZSH="${HOME}/.oh-my-zsh"

ZSH_THEME="robbyrussell"
#ZSH_THEME="agnoster"

DISABLE_AUTO_UPDATE="true"

## Options section
setopt correct

## Alias section
alias vi="vim"
alias df='df -h'
alias top='htop'

# Color of man pages
export LESS_TERMCAP_mb=$'\e[01;32m'
export LESS_TERMCAP_md=$'\e[01;32m'
export LESS_TERMCAP_me=$'\e[0m'
export LESS_TERMCAP_se=$'\e[0m'
export LESS_TERMCAP_so=$'\e[01;47;34m'
export LESS_TERMCAP_ue=$'\e[0m'
export LESS_TERMCAP_us=$'\e[01;36m'
export LESS=-r

export VISUAL='vim'
export EDITOR='vim'
export PAGER='less'

plugins=(git)
source $ZSH/oh-my-zsh.sh
