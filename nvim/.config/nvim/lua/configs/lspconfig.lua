local M = {}

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
  if client:supports_method("textDocument/semanticTokens") then
    client.server_capabilities.semanticTokensProvider = nil
  end
end

-- ---------------------------------------------------------------------------
-- on_attach  –  keymaps + per-filetype hooks
-- ---------------------------------------------------------------------------
M.on_attach = function(_, bufnr)
  if lsp_attached_buffers[bufnr] then return end
  lsp_attached_buffers[bufnr] = true

  require("keymaps").apply_buffer(bufnr, "lsp")

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
