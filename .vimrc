"###########################################################################
"                                    _
"                             _   __(_)___ ___  __________
"                            | | / / / __ `__ \/ ___/ ___/
"                            | |/ / / / / / / / /  / /__
"                            |___/_/_/ /_/ /_/_/   \___/

"                                written by <3 mo1ein

"############################################################################

filetype plugin on

set ls=2
set nocp
set nowrap
set t_Co=256
syntax enable
set noswapfile
set noerrorbells
set encoding=utf8
set clipboard=unnamed
set clipboard=+unnamedplus

" For Persian language
set termbidi

" Colorscheme
"colorscheme molokai
colorscheme neodark
"colorscheme dracula
"packadd! dracula

" molokai background transparency
" hi Normal guibg=NONE ctermbg=NONE
"let g:rehash256 = 1
"let g:molokai_original = 1
" for neodark transparency
"let g:neodark#terminal_transparent = 1


" Tab size
set tabstop=4 softtabstop=4 shiftwidth=4 expandtab


" Line numbers
set number
set relativenumber
set ruler
hi LineNr ctermbg=NONE ctermfg=blue


" Indent
set si
set cindent
set autoindent
set showmatch


" Search
set hlsearch
set ignorecase
hi Search ctermbg=51

" Highlight current line
set cursorline
hi CursorLine cterm=underline,bold ctermbg=NONE ctermfg=NONE


" Mouse
set mouse=a

" Resize vim panes with mouse inside tmux
set mouse+=a
if &term =~ '^screen'
    " tmux knows the extended mouse mode
    set ttymouse=xterm2
endif


" Colors in autocomplete
let g:ycm_use_clangd = 0
let g:ycm_confirm_extra_conf = 1
hi Pmenu ctermfg=NONE ctermbg=236 cterm=NONE guifg=NONE guibg=#64666d gui=NONE
hi PmenuSel ctermfg=NONE ctermbg=24 cterm=NONE guifg=NONE guibg=#204a87 gui=NONE
""highlight Pmenu ctermfg=15 ctermbg=0 guifg=#ffffff guibg=#000000


" Indent line
let g:indentLine_setColors = 1
let g:indentLine_color_term = 239
let g:indentLine_color_tty_light = 7 " (default: 4)
let g:indentLine_color_dark = 1 " (default: 2)
let g:indentLine_char_list = ['|', '¦', '┆', '┊']


" NerdTree
map <F9> :NERDTreeToggle<CR>
let g:nerdtreefileextensionhighlightfullname = 1

" Open file in new tab with ctrl + t
let NERDTreeMapOpenInTab='<c-t>'
let g:NERDTreeWinPos = "right"
let g:NERDTreeIndicatorMapCustom = {
    \ "Modified"  : "✹",
    \ "Staged"    : "✚",
    \ "Untracked" : "✭",
    \ "Renamed"   : "➜",
    \ "Unmerged"  : "═",
    \ "Deleted"   : "",
    \ "Dirty"     : "✗",
    \ "Clean"     : "✔︎",
    \ 'Ignored'   : '☒',
    \ "Unknown"   : "?"
    \ }

" Open a NERDTree automatically when vim starts up if no files were specified
autocmd StdinReadPre * let s:std_in=1
autocmd VimEnter * if argc() == 0 && !exists("s:std_in") | NERDTree | endif

" Close vim if the only window left open is a NERDTree
autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif


" ALE
let g:ale_fix_on_save = 1
let g:ale_lint_on_enter = 1
let g:ale_list_window_size = 5
let g:airline#extensions#ale#enabled = 1
let b:ale_warn_about_trailing_whitespace = 0

let g:ale_linters = {
  \ 'python': ['pycodestyle'],
  \ 'c': ['clang'],
  \'cpp': ['clang', 'g++']
  \ }

let g:ale_fixers = {
  \ 'python': ['autopep8'],
  \ '*': ['remove_trailing_lines', 'trim_whitespace']
  \ }

let g:ale_sign_error = '✘'
let g:ale_sign_warning = "◉"

hi SignColumn ctermbg=NONE
highlight ALEErrorSign ctermfg=9 ctermbg=NONE
highlight ALEWarningSign ctermfg=11 ctermbg=NONE


" Airline
"let g:airline_theme='minimalist' " set airline plugin theme
let g:airline_theme='dracula' " set airline plugin theme
let g:airline#extensions#tabline#enabled = 1
let g:airline_powerline_fonts = 1
let g:airline_exclude_preview = 1

if !exists('g:airline_symbols')
    let g:airline_symbols = {}
  endif


" Deoplete
let g:deoplete#enable_at_startup = 1
" <TAB>: completion.
inoremap <expr><TAB>  pumvisible() ? "\<C-n>" : "\<TAB>"


" vim markdown preview
let vim_markdown_preview_browser='firefox'


" Vimplayer
let g:default_player = 'mocp'


" Unicode symbols
let g:airline_left_sep = '»'
let g:airline_left_sep = '▶'
let g:airline_right_sep = '«'
let g:airline_right_sep = '◀'


" Key maps
" Paste mode toggle with F2
set pastetoggle=<F2>

"Going to normal mode with <jk> , <esc> is too far :)
inoremap jk <esc>
vnoremap jk <esc>

" Disable arrow movement, resize splits instead.
nnoremap <Up>    :resize -1<CR>
nnoremap <Down>  :resize +1<CR>
nnoremap <Left>  :vertical resize -1<CR>
nnoremap <Right> :vertical resize +1<CR>


" Auto complete for ( , " , ' , [ , {
inoremap        (  ()<Left>
inoremap        "  ""<Left>
inoremap        `  ``<Left>
inoremap        '  ''<Left>
inoremap        [  []<Left>
inoremap      {  {}<Left>


" Switch Between Tabs (with F3 and F4)
noremap <silent> #3 :tabprevious<CR>
noremap <silent> #4 :tabnext<CR>


" Reload config from ~/.vimrc
nnoremap jr :source $MYVIMRC<CR>


"so important for run plugins :))
execute pathogen#infect()


" Plugins
call plug#begin('~/.vim/plugged')
" You can add every plugin here and install it.
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'dracula/vim', { 'as': 'dracula' }
Plug 'ryanoasis/vim-devicons'
Plug 'preservim/nerdtree'
Plug 'dense-analysis/ale'
Plug 'ap/vim-css-color'
Plug 'Yggdroot/indentLine'
Plug 'tpope/vim-fugitive'
Plug 'xuhdev/vim-latex-live-preview'
Plug 'Xuyuanp/nerdtree-git-plugin'
Plug 'KeitaNakamura/neodark.vim'
Plug 'dhruvasagar/vim-zoom'
Plug 'junegunn/vim-slash'
Plug 'haya14busa/incsearch.vim'
Plug 'iamcco/markdown-preview.vim'
Plug 'mo1ein/Vimplayer'
"Plug 'ycm-core/YouCompleteMe'

"deoplete
Plug 'deoplete-plugins/deoplete-jedi'
Plug 'roxma/vim-hug-neovim-rpc'
Plug 'Shougo/deoplete-clangx'
Plug 'Shougo/deoplete.nvim'
Plug 'roxma/nvim-yarp'

Plug 'davidhalter/jedi-vim'
call plug#end()
