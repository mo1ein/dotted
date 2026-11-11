-- Pure contrast and sparse/reversed theme fallback tests; no external plugins.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(root)
local colors = require "ui.color"
assert(colors.contrast(0, 0xffffff) == 21)
assert(colors.contrast(0x222222, 0x222222) == 1)
for _, bg in ipairs { 0x000000, 0xffffff, 0x777777, 0x112233, 0x669988, 0xeedd99 } do
  assert(colors.contrast(colors.text_on(bg), bg) >= 4.5)
  assert(colors.contrast(colors.readable(bg, bg), bg) >= 4.5)
end
vim.g.colors_name = "synthetic"
vim.api.nvim_set_hl(0, "Normal", { fg = 0x222222, bg = 0x222222, reverse = true })
vim.api.nvim_set_hl(0, "StatusLine", { fg = 0, bg = 0xffffff, reverse = true })
vim.api.nvim_set_hl(0, "Function", { fg = 0x222222 })
require("ui.statusline_colors").apply()
local badge = vim.api.nvim_get_hl(0, { name = "DottedSt_NormalMode", link = false })
assert(colors.contrast(badge.fg, badge.bg) >= 4.5)
assert(not vim.api.nvim_get_hl(0, { name = "StatusLine", link = false }).reverse)
print "Colors: WCAG contrast, monochrome, reverse, and low-contrast fallback passed"
