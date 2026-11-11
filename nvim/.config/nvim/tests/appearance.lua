-- Integration: every theme keeps segmented statusline geometry/contrast and transparency.
-- Run after installing plugins, in isolated XDG directories.
local policy = require "config.transparency"
local colors = require "ui.color"
local catalog = require "themes.catalog"
local loader = require "config.theme_loader"
local original = loader.current()
assert(policy.enabled)
local function get(role) return vim.api.nvim_get_hl(0, { name = "DottedSt_" .. role, link = false }) end
local count = 0
for _, entry in ipairs(catalog.entries()) do
  for _, scheme in ipairs(entry.schemes) do
    vim.cmd.colorscheme(scheme)
    for _, name in ipairs { "Normal", "NormalNC", "NormalFloat", "SignColumn", "LineNr", "EndOfBuffer" } do
      assert(vim.api.nvim_get_hl(0, { name = name, link = false }).bg == nil, scheme .. " leaves an opaque " .. name)
    end
    for _, mode in ipairs { "Normal", "Insert", "Visual", "Replace", "Command", "Select", "Terminal", "NTerminal", "Confirm" } do
      local badge, edge = get(mode .. "Mode"), get(mode .. "ModeSep")
      assert(type(badge.fg) == "number" and type(badge.bg) == "number", scheme .. " has a transparent/undefined mode badge")
      assert(colors.contrast(badge.fg, badge.bg) >= 4.5, scheme .. " has unreadable " .. mode .. " text")
      assert(edge.fg == badge.bg and edge.bg == get("EmptySpace").fg, scheme .. " breaks the mode separator")
    end
    for _, role in ipairs { "file", "cwd_text", "pos_text" } do
      local attrs = get(role)
      assert(colors.contrast(attrs.fg, attrs.bg) >= 4.5, scheme .. " has unreadable " .. role)
    end
    for _, name in ipairs { "DottedBufActive", "DottedBufInactive" } do
      local attrs = vim.api.nvim_get_hl(0, { name = name, link = false })
      assert(colors.contrast(attrs.fg, attrs.bg) >= 4.5, scheme .. " has unreadable buffer tabs")
    end
    assert(get("file_sep").fg == get("file").bg and get("file_sep").bg == nil, scheme .. " breaks the file separator")
    assert(get("cwd_sep").fg == get("cwd_icon").bg and get("pos_sep").fg == get("pos_icon").bg, scheme .. " breaks right-hand separators")
    count = count + 1
  end
end
for _, scheme in ipairs { "dotted-onedark", "vscode-dark-2026", "catppuccin-mocha", "everforest", "github_light", "ghostty-dracula", "zed-one-dark" } do
  loader.apply(scheme)
  vim.cmd "TransparencyToggle"
  assert(not policy.enabled and vim.api.nvim_get_hl(0, { name = "Normal", link = false }).bg ~= nil, scheme .. " cannot restore an opaque background")
  vim.cmd "TransparencyToggle"
  assert(policy.enabled and vim.api.nvim_get_hl(0, { name = "Normal", link = false }).bg == nil)
end
-- User highlights must run after the policy, including after a late UI load.
local overrides = require "config.highlights"
overrides.groups.Normal = { bg = "#123456" }
loader.apply "vscode-dark-2026"
assert(vim.api.nvim_get_hl(0, { name = "Normal", link = false }).bg == 0x123456)
vim.api.nvim_exec_autocmds("User", { pattern = "LazyLoad", data = "nvim-tree.lua" })
assert(vim.api.nvim_get_hl(0, { name = "Normal", link = false }).bg == 0x123456)
overrides.groups.Normal = nil
loader.apply(original)
assert(vim.v.errmsg == "", vim.v.errmsg)
print(count .. " themes passed statusline contrast/geometry and transparency; toggle/override tests passed")
vim.cmd "qa!"
