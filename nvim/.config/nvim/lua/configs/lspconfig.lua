local M = {}
local map = vim.keymap.set
local lsp_attached_buffers = {}

-- core LSP components
M.capabilities = vim.lsp.protocol.make_client_capabilities()
M.capabilities.textDocument.completion.completionItem = {
  documentationFormat = { "markdown", "plaintext" },
  snippetSupport = true,
  preselectSupport = true,
  insertReplaceSupport = true,
  labelDetailsSupport = true,
  deprecatedSupport = true,
  commitCharactersSupport = true,
  tagSupport = { valueSet = { 1 } },
  resolveSupport = {
    properties = {
      "documentation",
      "detail",
      "additionalTextEdits",
    },
  },
}

M.on_init = function(client, _)
  if client.supports_method "textDocument/semanticTokens" then
    client.server_capabilities.semanticTokensProvider = nil
  end
end

M.on_attach = function(_, bufnr)
  if lsp_attached_buffers[bufnr] then return end
  lsp_attached_buffers[bufnr] = true

  local function opts(desc)
    return { buffer = bufnr, desc = "LSP " .. desc }
  end

  -- Auto-format Go files on save
  local filetype = vim.bo[bufnr].filetype
  if filetype == "go" then
    vim.api.nvim_create_autocmd("BufWritePre", {
      buffer = bufnr,
      callback = function()
        vim.cmd("GoFmt")
        -- OR use this instead of GoFmt if you prefer LSP-based formatting
        -- vim.lsp.buf.format({ async = false })
      end,
    })
  end


  -- Navigation
  map("n", "gD", vim.lsp.buf.declaration, opts "Go to declaration")
  map("n", "gd", vim.lsp.buf.definition, opts "Go to definition")
  map("n", "<leader>D", vim.lsp.buf.type_definition, opts "Go to type definition")
  map("n", "grr", "<cmd>FzfLua lsp_references<CR>", opts "References")
  map("n", "gri", "<cmd>FzfLua lsp_implementations<CR>", opts "Implementations")

  -- Workspace
  map("n", "<leader>wa", vim.lsp.buf.add_workspace_folder, opts "Add workspace folder")
  map("n", "<leader>wr", vim.lsp.buf.remove_workspace_folder, opts "Remove workspace folder")
  map("n", "<leader>wl", function()
    print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
  end, opts "List workspace folders")

  -- Code Actions
  map("n", "<leader>ca", vim.lsp.buf.code_action, opts "Code actions")
  map("n", "<leader>ra", require "nvchad.lsp.renamer", opts "Rename")
  map("n", "<leader>rn", vim.lsp.buf.rename, opts "Rename symbol")

  -- Documentation
  map("n", "K", function()
    vim.lsp.buf.hover({ border = "rounded" })
  end, opts "Hover documentation")

  -- LSP Management
  map("n", "<leader>cI", "<cmd>LspInfo<CR>", opts "LSP info")
  map("n", "<leader>vR", "<cmd>LspRestart<CR>", opts "Restart LSP")

-- Formatting
 map("n", "<leader>fm", function()
  vim.lsp.buf.format({ async = true, filter = function(client)
    -- Use Ruff for formatting
    return client.name == "ruff"
  end})
end, opts "Format buffer")
end

-- Setup LSP servers
M.setup_servers = function()
  local lspconfig = require("lspconfig")
  -- Setup each server
  lspconfig.lua_ls.setup(require("configs.servers.lua_ls"))
  lspconfig.gopls.setup(require("configs.servers.gopls"))
  lspconfig.pyright.setup(require("configs.servers.pyright"))
  lspconfig.ruff.setup(require("configs.servers.ruff"))
end

-- Main entry point
M.defaults = function()
  dofile(vim.g.base46_cache .. "lsp")
  require("nvchad.lsp").diagnostic_config()

  -- LSP attachment handler
  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("UserLspConfig", {}),
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if client then
        M.on_attach(client, args.buf)
      end
    end,
  })
  M.setup_servers()
end

return M

-- -- 5) nvim-cmp setup (completion)
-- vim.schedule(function()
--   local cmp = require("cmp")
--   cmp.setup({
--     snippet = {
--       expand = function(args)
--         require("luasnip").lsp_expand(args.body)
--       end,
--     },
--     mapping = {
--       ["<C-p>"]     = cmp.mapping.select_prev_item(),
--       ["<C-n>"]     = cmp.mapping.select_next_item(),
--       ["<C-d>"]     = cmp.mapping.scroll_docs(-4),
--       ["<C-f>"]     = cmp.mapping.scroll_docs(4),
--       ["<C-Space>"] = cmp.mapping.complete(),
--       ["<CR>"]      = cmp.mapping.confirm({ behavior = cmp.ConfirmBehavior.Replace, select = true }),
--       ["<Tab>"]     = cmp.mapping(function(fallback)
--                          if cmp.visible() then cmp.select_next_item()
--                          else fallback() end
--                        end, { "i", "s" }),
--       ["<S-Tab>"]   = cmp.mapping(function(fallback)
--                          if cmp.visible() then cmp.select_prev_item()
--                          else fallback() end
--                        end, { "i", "s" }),
--     },
--     sources = {
--       { name = "nvim_lsp" },
--       { name = "luasnip" },
--       { name = "buffer" },
--       { name = "path" },
--     },
--   })
-- end)

-- return M
