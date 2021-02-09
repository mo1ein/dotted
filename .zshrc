
export ZSH="/home/$HOME/.oh-my-zsh"

ZSH_THEME="robbyrussell"
#ZSH_THEME="agnosterme"

## Options section
setopt correct

## Alias section
alias vi="vim"
alias df='df -h'
alias top='htop'

# Color of man pages
export LESS_TERMCAP_mb=$'\E[01;32m'
export LESS_TERMCAP_md=$'\E[01;32m'
export LESS_TERMCAP_me=$'\E[0m'
export LESS_TERMCAP_se=$'\E[0m'
export LESS_TERMCAP_so=$'\E[01;47;34m'
export LESS_TERMCAP_ue=$'\E[0m'
export LESS_TERMCAP_us=$'\E[01;36m'
export LESS=-r

export VISUAL='vim'
export EDITOR='vim'
export PAGER='less'

plugins=(git)
source $ZSH/oh-my-zsh.sh
