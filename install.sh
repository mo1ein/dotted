#!/bin/bash

set -euo pipefail
IFS=$'\n\t'
shopt -s dotglob

# --------- env ---------

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$HOME"
PACKAGES_FILE="$DOTFILES_DIR/packages.txt"
CASKS_FILE="$DOTFILES_DIR/casks-mac.txt"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$HOME/.dotfiles-backup/$TIMESTAMP"
ONLY_PKGS=false
DRY_RUN=false
OS=""

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

log()  { echo -e "${GREEN}[info] $*${NC}"; }
err()  { echo -e "${RED}[error] $*${NC}" >&2; }

# --------- OS detection ---------

detect_os() {
  case "$(uname -s)" in
    Darwin) OS="macos" ;;
    Linux)  OS="linux" ;;
    *) err "Unsupported OS: $(uname -s). This installer supports macOS and Linux."; exit 1 ;;
  esac
  log "Detected OS: $OS"

  if [[ "$OS" == "macos" ]]; then
    PACKAGES_FILE="$DOTFILES_DIR/packages-mac.txt"
  fi
}

# --------- Helpers ---------

has_apt() {
  command -v apt-get >/dev/null 2>&1
}

# Portable readlink -f (macOS readlink doesn't support -f)
readlink_f() {
  local path="$1"
  local dirname_path target
  while [[ -L "$path" ]]; do
    target="$(readlink "$path")"
    if [[ "$target" != /* ]]; then
      path="$(dirname "$path")/$target"
    else
      path="$target"
    fi
  done
  dirname_path="$(dirname "$path")"
  if [[ "$dirname_path" == "." ]]; then
    dirname_path="$PWD"
  elif [[ "$dirname_path" != /* ]]; then
    dirname_path="$(cd "$dirname_path" && pwd)"
  fi
  echo "$dirname_path/$(basename "$path")"
}

ensure_homebrew() {
  if command -v brew >/dev/null 2>&1; then
    log "Homebrew is already installed."
    return 0
  fi

  log "Homebrew not found. Installing Homebrew (brew)..."
  if $DRY_RUN; then
    log "DRY RUN: would run the official Homebrew installer."
    return 0
  fi

  # The official installer also sets up the Xcode Command Line Tools when needed
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Make brew available in this session
  # Apple Silicon -> /opt/homebrew, Intel -> /usr/local
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

ensure_stow() {
  if command -v stow >/dev/null 2>&1; then
    return 0
  fi

  log "GNU stow not found. Installing..."

  if $DRY_RUN; then
    log "DRY RUN: would install 'stow' via the ${OS} package manager."
    return 0
  fi

  if [[ "$OS" == "macos" ]]; then
    ensure_homebrew
    brew install stow
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
    link_target="$(readlink_f "$dest")"
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
    link_target="$(readlink_f "$1")"
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
  tr -d '\r' < "$PACKAGES_FILE" | sed -e 's/#.*//' | awk 'NF'
}

read_casks() {
  tr -d '\r' < "$CASKS_FILE" | sed -e 's/#.*//' | awk 'NF'
}

# stow & neovim are required by this repo — installed before everything else
is_essential() {
  case "$1" in
    stow|neovim) return 0 ;;
    *) return 1 ;;
  esac
}

install_packages_linux() {
  local -a pkgs=("$@")

  if (( ${#pkgs[@]} == 0 )); then
    return 0
  fi

  log "Installing packages: ${pkgs[*]}"
  if sudo apt-get install -y --no-install-recommends -- "${pkgs[@]}"; then
    log "Packages installed successfully."
  else
    err "apt-get install failed."
    return 1
  fi
}

install_casks() {
  local -a casks=()
  local line
  while IFS= read -r line; do
    casks+=("$line")
  done < <(read_casks)

  if (( ${#casks[@]} == 0 )); then
    return 0
  fi

  log "Installing casks: ${casks[*]}"
  brew install --cask "${casks[@]}"
}

install_packages_macos() {
  local -a all=("$@")
  local -a essential=()
  local -a rest=()
  local pkg

  ensure_homebrew
  if ! command -v brew >/dev/null 2>&1; then
    err "brew is not available. Aborting package installation."
    return 1
  fi

  # stow & neovim first — we need them
  for pkg in "${all[@]}"; do
    if is_essential "$pkg"; then
      essential+=("$pkg")
    else
      rest+=("$pkg")
    fi
  done

  if (( ${#essential[@]} > 0 )); then
    log "Installing essential packages first: ${essential[*]}"
    brew install "${essential[@]}"
  fi

  if (( ${#rest[@]} > 0 )); then
    log "Installing packages: ${rest[*]}"
    brew install "${rest[@]}"
  fi

  install_casks
  log "Packages installed successfully."
}

install_packages() {
  local -a pkgs=()
  local line

  while IFS= read -r line; do
    pkgs+=("$line")
  done < <(read_packages)

  if (( ${#pkgs[@]} == 0 )); then
    log "No packages to install."
    return 0
  fi

  if [[ "$OS" == "macos" ]]; then
    # On macOS, install stow & neovim first (brew installs them sequentially)
    install_packages_macos "${pkgs[@]}"
  else
    # On Linux, apt installs everything in one transaction — order doesn't matter
    if ! has_apt; then
      err "apt-get not available. Skipping package installation."
      return 1
    fi
    sudo apt-get update -y
    install_packages_linux "${pkgs[@]}"
  fi
}


install_oh_my_zsh() {
    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        log "Installing Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
        if [[ "$OS" == "macos" ]]; then
            chsh -s /bin/zsh
        else
            chsh -s "$(which zsh)"
        fi
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
    detect_os

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
        if [[ "$OS" == "macos" ]]; then
            log "Skipping Linux-only extras (Gogh themes, Docker apt repo) on macOS."
        else
            install_gogh
            install_docker_on_deb
        fi
    fi
    log "Done."
}

main "$@"
