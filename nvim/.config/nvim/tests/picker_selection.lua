-- Breadcrumb colors follow existing selection roles without restyling pickers.
assert(vim.env.NVIM_TEST_ISOLATED == "1")
local selection = require "ui.breadcrumb_colors"
local colors = require "ui.color"
assert(not package.loaded["fzf-lua"], "Selection styling eagerly loaded the finder")
local function check_menu()
  local menu = require("ui.menu").open { selection = "DottedBreadcrumbSelection", items = { { label = "Selected item" } } }
  assert(vim.wo[menu.win].winhighlight:find("CursorLine:DottedBreadcrumbSelection", 1, true))
  assert(vim.api.nvim_get_hl(0, { name = "DottedBreadcrumbActive", link = true }).link == "DottedBreadcrumbSelection")
  assert(colors.get("DottedMenuCursor").bg == colors.get("DottedBreadcrumbSelection").bg, "Hidden caret uses a different selection background")
  menu:close()
end
local function existing_colors()
  local result = {}
  for _, group in ipairs { "CursorLine", "Visual", "PmenuSel", "NormalFloat", "FzfLuaCursorLine", "FzfLuaFzfCursorLine" } do
    result[group] = colors.get(group)
  end
  return result
end
local function apply_readonly()
  local before = existing_colors()
  selection.apply()
  check_menu()
  assert(vim.deep_equal(before, existing_colors()), "Breadcrumb colors modified an existing UI highlight")
end
-- Theme-specific finder overrides, including reverse, remain authoritative.
local original_global = vim.g.fzf_colors
local original_env, original_file = vim.env.FZF_DEFAULT_OPTS, vim.env.FZF_DEFAULT_OPTS_FILE
vim.env.FZF_DEFAULT_OPTS, vim.env.FZF_DEFAULT_OPTS_FILE = nil, nil
vim.api.nvim_set_hl(0, "FzfLuaFzfCursorLine", { fg = 0x123456, bg = 0x456789 })
vim.g.fzf_colors = nil
apply_readonly()
assert(colors.get("DottedBreadcrumbSelection").bg == 0x303030, "A Vim highlight not used by fzf incorrectly changed the breadcrumb palette")
vim.g.fzf_colors = { ["fg+"] = { "fg", "FzfLuaFzfCursorLine" }, ["bg+"] = { "bg", "FzfLuaFzfCursorLine" } }
apply_readonly()
assert(colors.get("DottedBreadcrumbSelection").fg == 0x123456 and colors.get("DottedBreadcrumbSelection").bg == 0x456789)
vim.api.nvim_set_hl(0, "FzfLuaFzfCursorLine", { fg = 0x112233, bg = 0xddeeff, reverse = true })
apply_readonly()
assert(colors.get("DottedBreadcrumbSelection").fg == 0xddeeff and colors.get("DottedBreadcrumbSelection").bg == 0x112233)
vim.g.fzf_colors = original_global
local custom = selection.resolve { fzf_opts = { ["--color"] = "fg+:#123abc,bg+:#234bcd", ["--no-bold"] = true } }
assert(custom.fg == 0x123abc and custom.bg == 0x234bcd and not custom.bold, "Explicit finder colors/style weren't respected")
vim.env.FZF_DEFAULT_OPTS = "--color='fg+:#456def,bg+:#567abc'"
custom = selection.resolve()
assert(custom.fg == 0x456def and custom.bg == 0x567abc, "Environment finder colors weren't respected")
vim.env.FZF_DEFAULT_OPTS, vim.env.FZF_DEFAULT_OPTS_FILE = original_env, original_file
for _, background in ipairs { "dark", "light" } do
  vim.o.background = background
  vim.cmd.colorscheme "default"
  local palette = colors.get "DottedBreadcrumbSelection"
  assert(palette.fg and palette.bg, "Theme switch lost the selected-row palette")
  apply_readonly()
end
require("lazy").load { plugins = { "fzf-lua" } }
for _, picker in ipairs { "files", "grep" } do
  local opts = require("fzf-lua.config").normalize_opts({}, picker)
  assert(opts.hls.cursorline == "FzfLuaCursorLine" and opts.hls.fzf.cursorline == "FzfLuaFzfCursorLine", "Original picker highlight roles were not restored")
  assert(not opts.fzf_colors["fg+"] and not opts.fzf_colors["bg+"], "Breadcrumb styling still overrides the picker selected-row colors")
end
apply_readonly()
local menu = require("ui.menu").open { items = { { label = "Unrelated tool menu" } } }
assert(vim.wo[menu.win].winhighlight:find("CursorLine:PmenuSel", 1, true), "Unrelated menus still use breadcrumb-specific colors")
menu:close()
local native = require("ui.theme_picker").open({ "Theme" }, { stop = function() end, cancel_if_idle = function() end })
assert(not vim.wo[native.win].winhighlight:find("Dotted", 1, true), "Native theme picker still has a breadcrumb color override")
vim.api.nvim_win_close(native.win, true)
assert(vim.v.errmsg == "", vim.v.errmsg)
print "Breadcrumb colors: original file/grep/theme/tool-menu styling preserved; read-only color inheritance, lazy loading, reverse and dark/light theme changes passed"
