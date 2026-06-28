#!/bin/bash

set -euo pipefail
IFS=$'\n\t'
shopt -s dotglob

# --------- env ---------

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$HOME"
PACKAGES_FILE="$DOTFILES_DIR/packages.txt"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$HOME/.dotfiles-backup/$TIMESTAMP"
ONLY_PKGS=false
DRY_RUN=false

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
    err "apt-get not available. Please install 'stow' manually."
    exit 1
  fi

  sudo apt-get update
  sudo apt-get install -y --no-install-recommends stow
}

# Given a repo file, compute where stow would place it in $HOME
# e.g. nvim/.config/nvim/init.lua -> ~/.config/nvim/init.lua
repo_to_target() {
  local src="$1"
  local rel="${src#"$DOTFILES_DIR/"}"
  rel="${rel#*/}"
  echo "$TARGET/$rel"
}

# Backup a single target path before stowing.
# Returns 0 if stow should proceed, 1 if already linked (skip).
backup_target() {
  local dest="$1"

  if [[ ! -e "$dest" && ! -L "$dest" ]]; then
    return 0
  fi

  if [[ -L "$dest" ]]; then
    local link_target
    link_target="$(readlink -f "$dest")"
    if [[ "$link_target" == "$DOTFILES_DIR"* ]]; then
      log "Already linked: $dest"
      return 1
    fi
    mkdir -p "$BACKUP_DIR"
    local rel="${dest#"$TARGET/"}"
    mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
    cp -a "$dest" "$BACKUP_DIR/$rel"
    rm -f "$dest"
    log "Backed up symlink: $dest -> $link_target"
    return 0
  fi

  mkdir -p "$BACKUP_DIR"
  local rel="${dest#"$TARGET/"}"
  mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
  cp -a "$dest" "$BACKUP_DIR/$rel"
  rm -rf "$dest"
  log "Backed up: $dest"
  return 0
}

# Check if path is already a symlink to our repo
is_linked() {
  if [[ -L "$1" ]]; then
    local link_target
    link_target="$(readlink -f "$1")"
    [[ "$link_target" == "$DOTFILES_DIR"* ]]
    return
  fi
  return 1
}

# Get stow target paths for a package (the fold points where stow creates symlinks)
stow_targets() {
  local pkg_dir="$1"
  for entry in "$pkg_dir"/*; do
    local name="$(basename "$entry")"
    [[ "$name" == ".git" ]] && continue
    if [[ -f "$entry" ]]; then
      echo "$TARGET/$name"
    elif [[ -d "$entry" ]]; then
      find_fold_points "$entry" "$name"
    fi
  done
}

find_fold_points() {
  local dir="$1"
  local path="$2"

  local has_files=false
  local -a subdirs=()
  for child in "$dir"/*; do
    [[ -e "$child" ]] || continue
    [[ "$(basename "$child")" == ".git" ]] && continue
    if [[ -f "$child" ]]; then
      has_files=true
    elif [[ -d "$child" ]]; then
      subdirs+=("$child")
    fi
  done

  if $has_files; then
    echo "$TARGET/$path"
    return
  fi

  for sub in "${subdirs[@]}"; do
    find_fold_points "$sub" "$path/$(basename "$sub")"
  done
}

# Link all dotfiles from all stow packages
link_all() {
  ensure_stow

  local backed_up=false
  local -a packages=()
  for pkg_dir in "$DOTFILES_DIR"/*/; do
    [[ -d "$pkg_dir" ]] || continue
    local pkg_name="$(basename "$pkg_dir")"
    [[ "$pkg_name" == .* ]] && continue
    packages+=("$pkg_name")

    # Check if any stow target for this package is already linked
    local all_linked=true
    while IFS= read -r target; do
      if ! is_linked "$target"; then
        all_linked=false
        break
      fi
    done < <(stow_targets "$pkg_dir")

    if $all_linked; then
      log "Already linked: $pkg_name"
      continue
    fi

    # Not linked — backup conflicting paths, then stow
    while IFS= read -r target; do
      backup_target "$target" || true
    done < <(stow_targets "$pkg_dir")

    backed_up=true
  done

  if $backed_up; then
    (cd "$DOTFILES_DIR" && stow -t "$TARGET" "${packages[@]}")
    log "Stowed all packages"
  else
    log "All files already linked"
  fi
}

# Restore the most recent backup
restore_backups() {
  local latest
  latest="$(ls -td "$HOME"/.dotfiles-backup/*/ 2>/dev/null | head -1)"

  if [[ -z "$latest" ]]; then
    err "No backups found in $HOME/.dotfiles-backup/"
    exit 1
  fi

  log "Restoring from: $latest"

  for pkg_dir in "$DOTFILES_DIR"/*/; do
    [[ -d "$pkg_dir" ]] || continue
    [[ "$(basename "$pkg_dir")" == .* ]] && continue
    (cd "$DOTFILES_DIR" && stow -D -t "$TARGET" "$(basename "$pkg_dir")") 2>/dev/null || true
  done

  while IFS= read -r backup_file; do
    local rel="${backup_file#"$latest"}"
    local dest="$TARGET/$rel"
    mkdir -p "$(dirname "$dest")"
    rm -rf "$dest"
    cp -a "$backup_file" "$dest"
    log "Restored: $dest"
  done < <(find "$latest" \( -type f -o -type l \))

  log "Restore complete"
}


# --------- Package Installation ---------

read_packages() {
  sed -e 's/\r$//' -e 's/#.*//' "$DOTFILES_DIR/packages.txt" | awk 'NF'
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
        chsh -s "$(which zsh)"
    else
        log "Oh My Zsh is already installed."
    fi
}


install_oh_my_zsh_plugins() {
    local custom="${ZSH_CUSTOM:-~/.oh-my-zsh/custom}"

    # autosuggestions
    if [[ ! -d "$custom/plugins/zsh-autosuggestions" ]]; then
        git clone https://github.com/zsh-users/zsh-autosuggestions \
          "$custom/plugins/zsh-autosuggestions"
    else
        log "zsh-autosuggestions already installed."
    fi

    # syntax highlighting
    if [[ ! -d "$custom/plugins/zsh-syntax-highlighting" ]]; then
        git clone https://github.com/zsh-users/zsh-syntax-highlighting \
          "$custom/plugins/zsh-syntax-highlighting"
    else
        log "zsh-syntax-highlighting already installed."
    fi
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


# --------- main ---------

main () {
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --install-pkgs|-i) ONLY_PKGS=true; shift ;;
        --restore) restore_backups; exit 0 ;;
        --dry-run) DRY_RUN=true; shift ;;
        *) err "Unknown option: $1"; exit 1 ;;
      esac
    done

    if ! $ONLY_PKGS; then
        link_all
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
