# dotted
### All my config files
## Usage

```
git clone https://github.com/mo1ein/dotted.git
cd dotted
```

* ## Neovim
    Finally I switched to neovim. :)

* ## Vim
  First , Install [Vim-plug](https://github.com/junegunn/vim-plug) then:
  ```
  cp .vimrc ~/
  mkdir -p ~/.vim/autoload && \
  curl -LSso ~/.vim/autoload/pathogen.vim https://tpo.pe/pathogen.vim
  ```
  For show icons install this font: https://www.nerdfonts.com/font-downloads
  ```
  sudo cp *.ttf /usr/share/fonts/
  sudo fc-cache -fv
  ```
  Go to vim and type : ``` :PlugInstall```to download plugins :)

* ## Zsh
  ```
  cp .zshrc ~/
  ```

* ## tmux
  ```
  cp .tmux.conf ~/
  ```

* ## git
  ```
  cp .config/git ~/.config/
  ```
  And
  ```
  cp .gitconfig ~/
  ```

* ## i3
  ```
  cp -r .config/i3 .config/i3status ~/.config/
  ```

* ## MOC
  ```
  cp config ~/.moc/
  ```
![alt text](https://github.com/mo1ein/My-dotfiles/blob/master/pic.png)
