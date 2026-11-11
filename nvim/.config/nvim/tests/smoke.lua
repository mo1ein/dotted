-- Headless regression checks. Run after plugins are installed; see README.
local function check()
  assert(vim.v.errmsg == "", vim.v.errmsg)
  for _, file in ipairs(vim.fn.glob(vim.fn.stdpath "config" .. "/**/*.lua", false, true)) do
    assert(loadfile(file))
  end

  local plugins = require("lazy.core.config").plugins
  for name, plugin in pairs(plugins) do
    assert(not plugin.url:lower():match("nvchad"), name .. " depends on a distribution")
  end
  assert(vim.g.base46_cache == nil)
  assert(not plugins["lualine.nvim"])
  assert(vim.o.statusline:find("ui.statusline", 1, true))
  local picker_map = vim.fn.maparg(" t", "n", false, true)
  assert(picker_map.rhs == "<Cmd>Theme<CR>" or picker_map.rhs == "<cmd>Theme<CR>")
  assert(picker_map.nowait == 1, "Space+t should open immediately, not wait for another key")
  local selected = require("config.theme_loader").startup()
  assert(require("config.theme_loader").current() == selected, "selected theme did not load")
  local overrides = require "config.highlights"
  overrides.groups.Comment = { bold = true }
  vim.cmd.colorscheme "habamax"
  assert(vim.g.colors_name == "habamax", "previous theme was forcibly reapplied")
  assert(vim.api.nvim_get_hl(0, { name = "Comment", link = false }).bold)
  vim.cmd.colorscheme(selected)
  assert(require("config.theme_loader").current() == selected)
  assert(vim.api.nvim_get_hl(0, { name = "Comment", link = false }).bold)
  overrides.groups.Comment = nil

  local keymaps = require "keymaps"
  for _, preset in ipairs(keymaps.available()) do
    for _, os in ipairs { "linux", "macos" } do
      assert(#keymaps.resolve(os, preset).bindings > 50)
    end
  end
  keymaps.setup()
  keymaps.setup() -- setup must not stack autocmds or fail on existing commands
  assert(#vim.api.nvim_get_autocmds { group = "KeymapsFiletype" } == 1)
  vim.cmd.enew()
  vim.bo.filetype = "lua"
  require("lazy").load {
    plugins = {
      "nvim-lspconfig", "nvim-cmp", "nvim-autopairs", "conform.nvim", "gitsigns.nvim",
      "nvim-tree.lua", "which-key.nvim", "fzf-lua",
      "grug-far.nvim", "nvim-dap", "mason.nvim", "render-markdown.nvim",
    },
  }
  assert(require("cmp").get_config().sources[1].name == "nvim_lsp")
  for _, server in ipairs { "lua_ls", "gopls", "pyright", "ruff" } do
    assert(type(vim.lsp.config[server].cmd) == "table", server .. " has no command")
  end
  local signs = vim.diagnostic.config().signs
  assert(type(signs) == "table" and signs.text[vim.diagnostic.severity.ERROR] == "󰅙"
    and signs.text[vim.diagnostic.severity.WARN] == "", "Diagnostic gutter icons weren't restored")
  -- Repeat after UI plugins are loaded to catch late theme-forcing hooks.
  vim.cmd.colorscheme "habamax"
  vim.wait(100)
  assert(vim.g.colors_name == "habamax", "a plugin forced the old theme back")
  assert(vim.tbl_contains(vim.fn.getcompletion("", "color"), "jb"), "jb is missing from :colorscheme completion")
  vim.cmd.colorscheme "jb"
  vim.wait(100)
  assert(vim.g.colors_name == "jb", "manual jb selection was overridden")
  assert(vim.o.statusline:find("ui.statusline", 1, true), "switching to jb replaced the statusline")
  vim.cmd.colorscheme "dotted-onedark"
  assert(vim.g.colors_name == "dotted-onedark")
  vim.cmd.colorscheme(selected)
  for _, pos in ipairs { "sp", "vsp", "float" } do
    local term = require "util.terminal"
    term.toggle { pos = pos, id = pos }
    local buf = vim.api.nvim_get_current_buf()
    assert(vim.bo[buf].buftype == "terminal")
    term.toggle { pos = pos, id = pos }
    assert(#vim.fn.win_findbuf(buf) == 0, "terminal did not hide")
    term.toggle { pos = pos, id = pos }
    assert(vim.api.nvim_get_current_buf() == buf, "terminal was not reused")
    vim.fn.jobstop(vim.b[buf].terminal_job_id)
    vim.api.nvim_buf_delete(buf, { force = true })
  end
  vim.wait(300)
  assert(vim.v.errmsg == "", vim.v.errmsg)
end

local ok, err = xpcall(check, debug.traceback)
if not ok then
  vim.api.nvim_err_writeln(err)
  vim.cmd "cquit 1"
else
  print "Smoke tests passed"
  vim.cmd "qa!"
end
