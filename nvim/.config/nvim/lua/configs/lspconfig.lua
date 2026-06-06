local M = {}
local map = vim.keymap.set

-- Tracks buffers that have already had LSP keymaps attached.
-- Guards against the rare double-fire when multiple servers attach to the
-- same buffer simultaneously (e.g. pyright + ruff on a Python file).
local lsp_attached_buffers = {}

-- ---------------------------------------------------------------------------
-- Capabilities
-- ---------------------------------------------------------------------------
M.capabilities = vim.lsp.protocol.make_client_capabilities()
M.capabilities.textDocument.completion.completionItem = {
  documentationFormat    = { "markdown", "plaintext" },
  snippetSupport         = true,
  preselectSupport       = true,
  insertReplaceSupport   = true,
  labelDetailsSupport    = true,
  deprecatedSupport      = true,
  commitCharactersSupport = true,
  tagSupport             = { valueSet = { 1 } },
  resolveSupport         = {
    properties = { "documentation", "detail", "additionalTextEdits" },
  },
}

-- ---------------------------------------------------------------------------
-- on_init  –  disable semantic tokens (let Treesitter own highlighting)
-- ---------------------------------------------------------------------------
M.on_init = function(client, _)
  if client.supports_method("textDocument/semanticTokens") then
    client.server_capabilities.semanticTokensProvider = nil
  end
end

-- ---------------------------------------------------------------------------
-- on_attach  –  keymaps + per-filetype hooks
-- ---------------------------------------------------------------------------
M.on_attach = function(_, bufnr)
  if lsp_attached_buffers[bufnr] then return end
  lsp_attached_buffers[bufnr] = true

  local function opts(desc)
    return { buffer = bufnr, desc = "LSP " .. desc }
  end

  -- Auto-format Go files on save (guard so we don't crash without vim-go)
  if vim.bo[bufnr].filetype == "go" then
    vim.api.nvim_create_autocmd("BufWritePre", {
      buffer = bufnr,
      callback = function()
        if vim.fn.exists(":GoFmt") == 2 then
          vim.cmd("GoFmt")
        else
          vim.lsp.buf.format({ async = false })
        end
      end,
    })
  end

  -- Navigation
  map("n", "gD",        vim.lsp.buf.declaration,               opts "Go to declaration")
  map("n", "gd",        vim.lsp.buf.definition,                opts "Go to definition")
  map("n", "<leader>D", vim.lsp.buf.type_definition,           opts "Go to type definition")
  map("n", "grr",       "<cmd>FzfLua lsp_references<CR>",      opts "References")
  map("n", "gri",       "<cmd>FzfLua lsp_implementations<CR>", opts "Implementations")

  -- Workspace
  map("n", "<leader>wa", vim.lsp.buf.add_workspace_folder,    opts "Add workspace folder")
  map("n", "<leader>wr", vim.lsp.buf.remove_workspace_folder, opts "Remove workspace folder")
  map("n", "<leader>wl", function()
    print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
  end, opts "List workspace folders")

  -- Code actions & rename  (kept nvchad renamer; dropped duplicate native map)
  map("n", "<leader>ca", vim.lsp.buf.code_action,         opts "Code actions")
  map("n", "<leader>rn", require("nvchad.lsp.renamer"),   opts "Rename")
  -- map("n", "<leader>rn", vim.lsp.buf.rename, opts "Rename symbol")

  -- Hover
  map("n", "K", function()
    vim.lsp.buf.hover({ border = "rounded" })
  end, opts "Hover documentation")

  -- LSP management
  map("n", "<leader>cI", "<cmd>LspInfo<CR>",    opts "LSP info")
  map("n", "<leader>vR", "<cmd>LspRestart<CR>", opts "Restart LSP")

  -- Format  –  filetype-aware so the filter makes sense on every buffer
  map("n", "<leader>fm", function()
    local ft = vim.bo[bufnr].filetype
    local filter = nil

    if ft == "python" then
      -- Prefer Ruff; fall back to any formatter if Ruff isn't attached
      local clients = vim.lsp.get_clients({ bufnr = bufnr })
      local has_ruff = vim.iter(clients):any(function(c) return c.name == "ruff" end)
      if has_ruff then
        filter = function(c) return c.name == "ruff" end
      end
    end

    vim.lsp.buf.format({ async = true, filter = filter })
  end, opts "Format buffer")
end

-- ---------------------------------------------------------------------------
-- Server setup  (Neovim 0.11+ vim.lsp.config / vim.lsp.enable API)
-- ---------------------------------------------------------------------------
M.setup_servers = function()
  local function load_cfg(name)
    local ok, cfg = pcall(require, "configs.servers." .. name)
    return ok and cfg or {}
  end

  local base = {
    capabilities = M.capabilities,
    on_init      = M.on_init,
  }

  local servers = {
    lua_ls  = { cmd = { "lua-language-server" },        filetypes = { "lua" } },
    gopls   = { cmd = { "gopls" },                      filetypes = { "go", "gomod", "gowork" } },
    pyright = { cmd = { "pyright-langserver", "--stdio" }, filetypes = { "python" } },
    ruff    = { cmd = { "ruff", "server" },             filetypes = { "python" } },
  }

  for name, extra in pairs(servers) do
    vim.lsp.config[name] = vim.tbl_deep_extend("force", base, extra, {
      settings = load_cfg(name),
    })
    vim.lsp.enable(name)
  end
end

-- ---------------------------------------------------------------------------
-- Entry point
-- ---------------------------------------------------------------------------
M.defaults = function()
  dofile(vim.g.base46_cache .. "lsp")
  require("nvchad.lsp").diagnostic_config()

  vim.api.nvim_create_autocmd("LspAttach", {
    group    = vim.api.nvim_create_augroup("UserLspConfig", { clear = true }),
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
