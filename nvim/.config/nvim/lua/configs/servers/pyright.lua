local util = require("lspconfig/util")

return {
  capabilities = require("configs.lspconfig").capabilities,
  on_attach = require("configs.lspconfig").on_attach,
  on_init = require("configs.lspconfig").on_init,
  filetypes = { "python" },
  root_dir = function(fname)
    return util.root_pattern("pyproject.toml", "setup.py", "requirements.txt", ".git")(fname) or vim.loop.cwd()
  end,
  single_file_support = true,
  settings = {
    pyright = {
        disableOrganizeImports = true, -- Using Ruff
    },
    python = {
      analysis = {
        ignore = {'*'},
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
        diagnosticMode = "workspace",
        -- Add these to improve autocompletion
        typeCheckingMode = "basic",
        autoImportCompletions = true,
        inlayHints = {
          variableTypes = true,
          functionReturnTypes = true,
        },
      },
    },
  },
}
