-- Dependency-free OneDark parity/switching tests; run with nvim -u NONE -l.
-- Hashes come from upstream's resolved definitions, not from the port itself.
local config = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(config)
local theme = require "themes.onedark"
local function fingerprint(groups)
  local lines = {}
  for _, name in ipairs(vim.fn.sort(vim.tbl_keys(groups))) do
    local props = { name }
    for _, key in ipairs(vim.fn.sort(vim.tbl_keys(groups[name]))) do
      props[#props + 1] = key .. "=" .. tostring(groups[name][key])
    end
    lines[#lines + 1] = table.concat(props, "|")
  end
  return vim.fn.sha256(table.concat(lines, "\n"))
end
local hashes = {
  opaque = "4f207f12ac51f27db2afc49e713293ffe8bb1aa0331e7cc0ffb32e9f9fda586b",
  transparent = "4829ea94fc27520dd360cd43c29b26a4532ad43f67bf7f528b4d0b5cad926371",
}
local statusline_hashes = {
  opaque = "c130a4747dbb7b95d6043909b34729a27979a41514ad5620a37bf66a5bed91dc",
  transparent = "854572ab23ef93199ce08aa219c63f4e948daf83c5ab31aed113261f415984e3",
}
for _, transparent in ipairs { false, true } do
  local groups = theme.highlights(transparent)
  local editor, statusline = {}, {}
  for name, attrs in pairs(groups) do
    local target = (name:match "^DottedSt_" or name == "StatusLine" or name == "StatusLineNC") and statusline or editor
    target[name] = attrs
  end
  local mode = transparent and "transparent" or "opaque"
  assert(vim.tbl_count(editor) == 325 and vim.tbl_count(statusline) == 36)
  assert(fingerprint(editor) == hashes[mode], "upstream editor highlights changed")
  assert(fingerprint(statusline) == statusline_hashes[mode], "upstream statusline highlights changed")
  theme.setup { transparent = transparent }
  vim.cmd.colorscheme "dotted-onedark"
  assert(vim.g.colors_name == "dotted-onedark")
  local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
  assert(normal.fg == 0xabb2bf)
  if transparent then
    assert(normal.bg == nil, "transparent Normal has a background")
  else
    assert(normal.bg == 0x1e222a, "opaque background differs from upstream")
  end
  local expected_terminal = {
    "#353b45", "#e06c75", "#98c379", "#e5c07b", "#61afef", "#c678dd", "#56b6c2", "#abb2bf",
    "#545862", "#e06c75", "#98c379", "#e5c07b", "#61afef", "#c678dd", "#56b6c2", "#c8ccd4",
  }
  for i, color in ipairs(expected_terminal) do assert(vim.g["terminal_color_" .. (i - 1)] == color) end
end
-- Test public override ordering and switching without lazy.nvim or plugins.
require("config.highlights").setup()
require("config.highlights").groups.Comment = { italic = true }
vim.cmd.colorscheme "dotted-onedark"
assert(vim.api.nvim_get_hl(0, { name = "Comment", link = false }).italic)
vim.cmd.colorscheme "habamax"
vim.wait(100)
assert(vim.g.colors_name == "habamax", "local theme forced itself back")
vim.cmd.colorscheme "dotted-onedark"
assert(vim.g.colors_name == "dotted-onedark")
assert(not package.loaded.base46 and not package.loaded.nvconfig)
assert(vim.v.errmsg == "", vim.v.errmsg)
print "OneDark: 361 upstream editor/statusline highlights match in both modes; terminal colors, overrides, and switching passed"
