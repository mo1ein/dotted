local util = require("lspconfig/util")

return {
  capabilities = require("configs.lspconfig").capabilities,
  on_init = require("configs.lspconfig").on_init,
  on_attach = require("configs.lspconfig").on_attach,
  filetypes = { "go", "gomod", "gosum" },
  settings = {
    gopls = {
      analyses = { unusedparams = true },
      staticcheck = true,
      gofumpt = true,
    },
  },
  root_dir = function(fname)
    return util.root_pattern("go.work", "go.mod", ".git")(fname) or util.path.dirname(fname)
  end,
  single_file_support = true,
}
