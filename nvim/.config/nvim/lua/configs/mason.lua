dofile(vim.g.base46_cache .. "mason")

return {
  { "mason-org/mason.nvim", version = "^1.0.0" },
  { "mason-org/mason-lspconfig.nvim", version = "^1.0.0" },
  PATH = "skip",

  ui = {
    icons = {
      package_pending = " ",
      package_installed = " ",
      package_uninstalled = " ",
    },
  },
  ensure_installed = {
    "lua_ls",
    "gopls",
    "ruff",
    "pyright",
  },
  automatic_installation = true,
  max_concurrent_installers = 10,
}
