-- Startup order only; each concern owns its own settings and lifecycle.
if vim.fn.has "nvim-0.12" == 0 then
  error "This configuration requires Neovim 0.12+ (current stable)."
end
vim.g.mapleader = " "
vim.g.maplocalleader = ","

require "options"
require("autocmds").setup()
require("ui.buffers").setup()
require("ui.switcher").setup()
if require("config.ui").breadcrumbs then
  require("ui.breadcrumbs").setup()
end
require("ui.statusline").setup()
if require("config.ui").bufferline then
  require("ui.bufferline").setup()
end
if require("config.ui").dashboard then
  require("ui.dashboard").setup()
end
if require("config.ui").tools.enabled then
  require("ui.tools").setup()
end
require("ui.transparency").setup()
require("config.highlights").setup()
require("ui.breadcrumb_colors").setup()
require("keymaps").setup()
require("ui.replace").setup()
require("config.theme_loader").setup()
require("config.lazy").setup()
