local util = require("lspconfig/util")

return {
  capabilities = require("configs.lspconfig").capabilities,
  on_init = require("configs.lspconfig").on_init,
  on_attach = require("configs.lspconfig").on_attach,
  filetypes = { "python" },
  root_dir = function(fname)
    return util.root_pattern("pyproject.toml", "setup.py", "requirements.txt", ".git")(fname) or vim.loop.cwd()
  end,
  single_file_support = true,
  init_options = {
    settings = {
    -- todo...
      args = { "--ignore=E501" }
    }
  }
}

