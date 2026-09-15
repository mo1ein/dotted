
ZSH_THEME="robbyrussell"
#ZSH_THEME="agnoster"

## Options section
setopt correct
unsetopt correct_all

export ZSH="${HOME}/.oh-my-zsh"
export PATH="$PATH:/usr/local/go/bin"
export GOPATH="$HOME/go"
export PATH="$PATH:$GOPATH/bin"
if command -v nvim >/dev/null 2>&1; then
  export VISUAL='nvim'
  export EDITOR='nvim'
else
  export VISUAL='vi'
  export EDITOR='vi'
fi
export PAGER='less'

# Aliases
command -v nvim >/dev/null 2>&1 && alias vi="nvim" && alias vim="nvim"
alias ls="ls -a"
alias df='df -h'
alias top='htop'

ENABLE_CORRECTION="false"
DISABLE_AUTO_UPDATE="true"

plugins=(git zsh-autosuggestions zsh-syntax-highlighting colored-man-pages)
fpath=(${HOME}/.zsh/completions $fpath)
source $ZSH/oh-my-zsh.sh
export PATH="$HOME/.local/bin:$PATH"


# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# kimi-code
export PATH="$HOME/.kimi-code/bin:$PATH"

# opencode
export PATH=$HOME/.opencode/bin:$PATH

# mimocode
export PATH=$HOME/.mimocode/bin:$PATH

# v2rayN mixed inbound (127.0.0.1:10808). TUN is blocked while Cisco AnyConnect is up,
# so terminal apps need these env vars; Chrome already follows the system/PAC proxy.
proxy_on() {
  export ALL_PROXY="socks5://127.0.0.1:10808"
  export all_proxy="$ALL_PROXY"
  export HTTP_PROXY="http://127.0.0.1:10808"
  export HTTPS_PROXY="$HTTP_PROXY"
  export http_proxy="$HTTP_PROXY"
  export https_proxy="$HTTP_PROXY"
  export NO_PROXY="localhost,127.0.0.1,::1"
  export no_proxy="$NO_PROXY"
}
proxy_off() {
  unset ALL_PROXY all_proxy HTTP_PROXY HTTPS_PROXY http_proxy https_proxy NO_PROXY no_proxy
}
