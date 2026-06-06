-- local util = require("lspconfig/util")
--
-- return {
--   capabilities = require("configs.lspconfig").capabilities,
--   on_init = require("configs.lspconfig").on_init,
--   on_attach = require("configs.lspconfig").on_attach,
--   filetypes = { "python" },
--   root_dir = function(fname)
--     return util.root_pattern("pyproject.toml", "setup.py", "requirements.txt", ".git")(fname) or vim.loop.cwd()
--   end,
--   single_file_support = true,
--   init_options = {
--     settings = {
--     -- todo...
--       args = { "--ignore=E501" }
--     }
--   }
-- }
--
-- configs/servers/ruff.lua
-- Pure settings only. root_dir, cmd, filetypes, capabilities live in lspconfig.lua.
-- Ruff's server config goes under init_options, not settings —
-- but init_options is also serialised directly, so keep it plain data.

return {
  -- NOTE: ruff-server reads its config from pyproject.toml / ruff.toml.
  -- init_options here only covers server-level knobs, not lint rules.
  -- Leave empty unless you need to override something not in your ruff config file.
}
