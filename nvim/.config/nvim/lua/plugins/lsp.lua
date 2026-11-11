-- Native LSP configuration plus an on-demand tool installer (no auto-installs).
return {
  { "mason-org/mason.nvim", cmd = { "Mason", "MasonInstall", "MasonUpdate" },
    opts = function() return require "configs.mason" end },
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = { "hrsh7th/cmp-nvim-lsp" },
    config = function() require("configs.lspconfig").setup() end,
  },
}
