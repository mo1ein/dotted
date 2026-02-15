
ZSH_THEME="robbyrussell"
#ZSH_THEME="agnoster"

## Options section
setopt correct

export ZSH="${HOME}/.oh-my-zsh"
export PATH="$PATH:/usr/local/go/bin"
export GOPATH="$HOME/go"
export PATH="$PATH:$GOPATH/bin"
export VISUAL='nvim'
export EDITOR='nvim'
export PAGER='less'

# Aliases
alias vi="nvim"
alias vim="nvim"
alias ls="ls -a"
alias df='df -h'
alias top='htop'

ENABLE_CORRECTION="true"
DISABLE_AUTO_UPDATE="true"

plugins=(git zsh-autosuggestions zsh-syntax-highlighting colored-man-pages)
source $ZSH/oh-my-zsh.sh
