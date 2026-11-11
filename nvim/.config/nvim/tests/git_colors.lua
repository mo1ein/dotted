-- Offline checks for pre-migration Git symbols, number colors, and theme changes.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(root)
local config = require "configs.gitsigns"
for name, icon in pairs { add = "┃", change = "┃", delete = "󰍵", topdelete = "‾", changedelete = "󱕖", untracked = "┆" } do
  assert(config.signs[name].text == icon, "Wrong Git sign: " .. name)
end
assert(config.numhl)
local colors = require "ui.git_colors"
local function hl(group) return vim.api.nvim_get_hl(0, { name = group, link = false }) end
colors.setup()
colors.setup()
assert(#vim.api.nvim_get_autocmds { group = "OwnedGitColors" } == 1)
vim.cmd.colorscheme "dotted-onedark"
vim.wait(50)
for target, source in pairs {
  GitSignsAdd = "DiffAdd", GitSignsChange = "DiffChange", GitSignsDelete = "DiffDelete",
  GitSignsChangedelete = "DiffChange", GitSignsTopdelete = "DiffDelete", GitSignsUntracked = "Comment",
  GitSignsAddNr = "DiffAdd", GitSignsChangeNr = "DiffChange", GitSignsDeleteNr = "DiffDelete",
} do
  assert(hl(target).fg == hl(source).fg and hl(target).bg == nil, "Wrong original Git color: " .. target)
end
vim.cmd.colorscheme "habamax"
vim.wait(50)
assert(hl("GitSignsAdd").fg == (hl("DiffAdd").fg or hl("Added").fg or 0x73bd79))
local overrides = require "config.highlights"
overrides.groups.GitSignsAdd = { fg = "#123456" }
vim.cmd.colorscheme "dotted-onedark"
vim.wait(50)
assert(hl("GitSignsAdd").fg == 0x123456, "Git adaptation overwrote user highlights")
overrides.groups.GitSignsAdd = nil
assert(vim.v.errmsg == "", vim.v.errmsg)
print "Git gutter: original symbols/colors, colored numbers, theme changes, and user overrides passed"
