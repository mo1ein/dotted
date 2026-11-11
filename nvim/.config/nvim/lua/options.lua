-- Editor defaults only; plugins and colors are configured elsewhere.
local opt = vim.opt
local o = vim.o
local g = vim.g

-- Disable netrw before runtime plugins load; NvimTree is opened on demand.
g.loaded_netrw = 1
g.loaded_netrwPlugin = 1

-------------------------------------- options ------------------------------------------
o.laststatus = 3
o.showmode = false
o.termguicolors = true
o.completeopt = "menu,menuone,noselect"
o.splitkeep = "screen"

o.clipboard = "unnamedplus"
o.cursorline = true
o.cursorlineopt = "both"
-- Blink in every mode while retaining the insert-mode bar.
o.guicursor = "n-v-c:block-blinkwait700-blinkoff400-blinkon250,i-ci-ve:ver25-blinkwait700-blinkoff400-blinkon250,r-cr:hor20-blinkwait700-blinkoff400-blinkon250,o:hor50-blinkwait700-blinkoff400-blinkon250"
o.hlsearch = true
o.incsearch = true

-- Indenting
o.expandtab = true
o.shiftwidth = 4
o.smartindent = true
o.tabstop = 4
o.softtabstop = 4

opt.fillchars = { eob = " " }
o.ignorecase = true
o.smartcase = true
o.mouse = "a"

-- Numbers
o.number = true
o.numberwidth = 2
o.relativenumber = true
o.ruler = false

-- disable nvim intro
opt.shortmess:append "sI"

o.signcolumn = "yes"
o.splitbelow = true
o.splitright = true
o.timeoutlen = 400
o.undofile = true

-- interval for writing swap file to disk, also used by gitsigns
o.updatetime = 250

-- go to previous/next line with h,l,left arrow and right arrow
-- when cursor reaches end/beginning of line
opt.whichwrap:append "<>[]hl"

-- disable some default providers
g.loaded_node_provider = 0
g.loaded_python3_provider = 0
g.loaded_perl_provider = 0
g.loaded_ruby_provider = 0

-- add binaries installed by mason.nvim to path
local is_windows = vim.fn.has "win32" ~= 0
local sep = is_windows and "\\" or "/"
local delim = is_windows and ";" or ":"
vim.env.PATH = table.concat({ vim.fn.stdpath "data", "mason", "bin" }, sep) .. delim .. vim.env.PATH

g.go_lint_mode = "off"
g.go_lint_autosave = 0
g.go_fmt_autosave = 0
g.go_metalinter_enabled = {}
