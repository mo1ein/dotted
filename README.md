# dotted


All my . files managed in one place using the [GNU Stow](https://www.gnu.org/software/stow/) pattern and an automated installer.
Each configuration lives in its own directory (a “stow package”) and is symlinked into `$HOME`, making it easy to manage, version, and reproduce my environment.

This repository acts as a single source of truth, allowing me to sync and bootstrap the same setup across multiple machines by changing and maintaining just one source.

<p align="center">
  <img src="./dotted.png" width="450" height="450" />
</p>

## Installation

```
git clone https://github.com/mo1ein/dotted.git
cd dotted
```

```
chmod +x install.sh
./install.sh
```

> [!NOTE]
> Existing dotfiles are automatically backed up before creating symlinks to the new configuration files.

Or if you want to install OS packages:

```
./install.sh --install-pkgs
```

And If you want to restore backup:

```
./install.sh --restore
```
easy peasy lemon squeezy!
