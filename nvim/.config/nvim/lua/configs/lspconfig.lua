-- Native LSP lifecycle. Server definitions come from nvim-lspconfig, not a distro.
local M = {}

function M.setup()
  local severity = vim.diagnostic.severity
  vim.diagnostic.config {
    severity_sort = true,
    virtual_text = { spacing = 2, source = "if_many" },
    float = { border = "rounded", source = true },
    underline = true,
    -- Preserve the former NvChad diagnostic icons, without its runtime dependency.
    signs = {
      text = {
        [severity.ERROR] = "󰅙",
        [severity.WARN] = "",
        [severity.INFO] = "󰋼",
        [severity.HINT] = "󰌵",
      },
    },
    update_in_insert = false,
  }
  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("UserLsp", { clear = true }),
    callback = function(args)
      require("keymaps").apply_buffer(args.buf, "lsp")
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if client and client.name == "ruff" then
        client.server_capabilities.hoverProvider = false
      end
    end,
  })
  local caps = vim.lsp.protocol.make_client_capabilities()
  local ok, cmp = pcall(require, "cmp_nvim_lsp")
  if ok then
    caps = cmp.default_capabilities(caps)
  end
  for _, name in ipairs { "lua_ls", "gopls", "pyright", "ruff" } do
    vim.lsp.config(name, {
      capabilities = caps,
      settings = require("configs.servers." .. name),
    })
    -- Don't spawn missing executables. After installing tools, reopen the file.
    local cmd = vim.lsp.config[name].cmd
    if type(cmd) == "table" and vim.fn.executable(cmd[1]) == 1 then
      vim.lsp.enable(name)
    end
  end
end

return M
