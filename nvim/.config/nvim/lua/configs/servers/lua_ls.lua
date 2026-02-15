return {
  capabilities = require("configs.lspconfig").capabilities,
  on_init = require("configs.lspconfig").on_init,
  on_attach = require("configs.lspconfig").on_attach,
  settings = {
    Lua = {
      runtime = { version = "LuaJIT" },
      workspace = {
        library = {
          vim.fn.expand "$VIMRUNTIME/lua",
          vim.fn.stdpath "data" .. "/lazy/ui/nvchad_types",
          vim.fn.stdpath "data" .. "/lazy/lazy.nvim/lua/lazy",
          "${3rd}/luv/library",
        },
        checkThirdParty = false,
      },
    },
  },
  single_file_support = true,
}
