#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

# --------- env ---------

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$HOME"
PACKAGES_FILE="$DOTFILES_DIR/packages.txt"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$HOME/.dotfiles-backup/$TIMESTAMP"
ONLY_PKGS=false

RED='\033[0;31m' 
GREEN='\033[0;32m'
NC='\033[0m'

log()  { echo -e "${GREEN}[info] $*${NC}"; }
err()  { echo -e "${RED}[error] $*${NC}" >&2; }


# --------- Helpers ---------

has_apt() {
  command -v apt-get >/dev/null 2>&1
}

ensure_stow() {
  if command -v stow >/dev/null 2>&1; then
    return 0
  fi

  log "GNU stow not found. Installing via apt..."

  if $DRY_RUN; then
    log "DRY RUN: sudo apt-get update && sudo apt-get install -y --no-install-recommends stow"
    return 0
  fi

  if ! has_apt; then
    error "apt-get not available. Please install 'stow' manually."
    exit 1
  fi

  sudo apt-get update
  sudo apt-get install -y --no-install-recommends stow
}

# example read_packages: strips comments (leading `#` or inline `#`) and blank lines
read_packages() {
  # read from packages.txt (or change to whatever source your read_packages used)
  sed -e 's/\r$//' -e 's/#.*//' packages.txt | awk 'NF'
}

install_packages() {
  local -a pkgs

  # read_packages should output one package per line; mapfile -> array
  mapfile -t pkgs < <(read_packages)

  if (( ${#pkgs[@]} == 0 )); then
    log "No packages to install."
    return 0
  fi

  if ! has_apt; then
    err "apt-get not available. Skipping package installation."
    return 1
  fi

  log "Installing packages: ${pkgs[*]}"
  sudo apt-get update -y

  # -- prevents pkg names that begin with '-' from being parsed as options
  if sudo apt-get install -y --no-install-recommends -- "${pkgs[@]}"; then
    log "Packages installed successfully."
  else
    err "apt-get install failed."
    return 1
  fi
}


install_oh_my_zsh() {
    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        log "Installing Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
        chsh -s $(which zsh)
    else
        log "Oh My Zsh is already installed."
    fi
}


install_oh_my_zsh_plugins() {
    # autosuggestions
    git clone https://github.com/zsh-users/zsh-autosuggestions \
	  ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

    # syntax highlighting
    git clone https://github.com/zsh-users/zsh-syntax-highlighting \
	  ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
}


install_gogh() {
    if [[ ! -d "$HOME/.gogh" ]]; then
        echo "Installing Gogh..."
        local tmp_dir
        tmp_dir="$(mktemp -d)"
        git clone https://github.com/Gogh-Co/Gogh.git "$tmp_dir/gogh"
        export TERMINAL="${TERMINAL:-gnome-terminal}"
        for theme in "$tmp_dir/gogh/installs"/*.sh; do
            echo "→ $(basename "$theme")"
            bash "$theme"
        done
    else
        echo "Gogh is already installed."
    fi
}
install_docker_on_deb() {
    # Try to remove old packages (ignore failures)
    sudo apt remove -y docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc || true

    # Add Docker's official GPG key and repo
    sudo apt update
    sudo apt install -y ca-certificates curl

    # create keyrings dir
    sudo install -m 0755 -d /etc/apt/keyrings

    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources (here-doc delimiter must start at column 0)
    sudo tee /etc/apt/sources.list.d/docker.sources > /dev/null <<'EOF'
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}


collect_dirs() {
    # find config dirs except .git files
    find . -mindepth 3 -maxdepth 3 -print | grep -v '/\.git/'
}


collect_dotfiles() {
  find "$DOTFILES_DIR" -maxdepth 1 -mindepth 1 -type f -name ".*" \
    ! -name "install.sh" \
    ! -name "README.md" \
    ! -name "LICENSE" \
    -printf '%f\n'
}


backup_dotfiles() {
  for file in $(collect_dotfiles); do
    dest="$TARGET/$file"
    if [[ -e "$dest" || -L "$dest" ]]; then
        mkdir -p "$BACKUP_DIR"
        mv -f "$dest" "$BACKUP_DIR"
        log "Backed up $dest"
    else 
        err "$dest: file or directory does not exist"
    fi
  done

  for dir in $(collect_dirs); do
    # remove leading ./
    rel="${dir#./}"
    # remove first directory
    rel="${rel#*/}"
    dest="$TARGET/$rel"
    if [[ -e "$dest" || -L "$dest" ]]; then
      backup_dest="$BACKUP_DIR/.config"
      mkdir -p "$backup_dest"
      mv -f "$dest" "$backup_dest"
      log "Backed up $dest"
    else 
      err "$dest: file or directory does not exist"
    fi
  done
}


stow_all() {
    ensure_stow
    stow -t "$TARGET" */
    log "Stowed all packages"
}


# --------- main ---------

main () {
    # --------- Flags ---------
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --install-pkgs|-i) ONLY_PKGS=true; shift ;;
        *) error "Unknown option: $1"; exit 1 ;;
      esac
    done

    if ! $ONLY_PKGS; then
        backup_dotfiles
        stow_all
    else
        install_packages
        install_oh_my_zsh
	install_oh_my_zsh_plugins
        install_gogh
	install_docker_on_deb
    fi
    log "Done."
}

main "$@"

