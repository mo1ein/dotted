-- Owned colorscheme loader: plain highlights, no framework, cache, or hooks.
local M = {}
local options = { transparent = true }

function M.setup(opts)
  options = vim.tbl_extend("force", { transparent = true }, opts or {})
end

function M.highlights(transparent)
  local groups = {}
  for _, part in ipairs { "core", "syntax", "plugins" } do
    for name, attrs in pairs(require("themes.onedark." .. part)) do
      groups[name] = vim.deepcopy(attrs)
    end
  end
  if transparent then
    for name, attrs in pairs(require "themes.onedark.transparency") do
      if name:match "^@ibl%.scope%.underline%." then
        groups[name] = vim.deepcopy(attrs)
      else
        groups[name] = vim.tbl_extend("force", groups[name] or {}, attrs)
      end
    end
  end
  for name, attrs in pairs(require("themes.onedark.statusline")(transparent)) do groups[name] = attrs end
  return groups
end

function M.load()
  -- Remove the old scheme name first so changing 'background' cannot reload it.
  vim.g.colors_name = nil
  vim.o.background = "dark"
  vim.o.termguicolors = true
  vim.cmd "highlight clear"
  if vim.g.syntax_on then vim.cmd "syntax reset" end
  vim.g.colors_name = "dotted-onedark"
  for name, attrs in pairs(M.highlights(options.transparent)) do
    vim.api.nvim_set_hl(0, name, attrs)
  end
  local s = require("themes.onedark.palette").syntax
  local terminal = {
    s.base01, s.base08, s.base0B, s.base0A, s.base0D, s.base0E, s.base0C, s.base05,
    s.base03, s.base08, s.base0B, s.base0A, s.base0D, s.base0E, s.base0C, s.base07,
  }
  for i, color in ipairs(terminal) do vim.g["terminal_color_" .. (i - 1)] = color end
end

return M
