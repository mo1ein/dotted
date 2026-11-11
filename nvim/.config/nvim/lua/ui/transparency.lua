-- Remove editor/pane backgrounds after theme setup, before user overrides.
-- Runs on theme changes and relevant UI plugin loads, never per cursor/frame.
local M = {}
local groups = { "Normal", "NormalNC", "SignColumn", "EndOfBuffer", "LineNr", "CursorLineNr", "FoldColumn", "WinSeparator", "WinBar", "WinBarNC", "CursorLine", "Folded" }
local floats = { "NormalFloat", "FloatBorder", "FzfLuaNormal", "FzfLuaBorder", "MasonNormal" }
local sidebars = { "NvimTreeNormal", "NvimTreeNormalNC", "NvimTreeEndOfBuffer", "NvimTreeWinSeparator", "NvimTreeCursorLine", "NeoTreeNormal", "NeoTreeNormalNC" }

function M.apply()
  local config = require "config.transparency"
  if not config.enabled then return end
  local function clear(group)
    local attrs = require("ui.color").get(group)
    if not next(attrs) and group ~= "NormalNC" then return end
    if group == "NormalNC" and not next(attrs) then attrs = require("ui.color").get "Normal" end
    attrs.bg, attrs.ctermbg, attrs.default = nil, nil, nil
    if attrs.cterm then attrs.cterm.reverse, attrs.cterm.standout = nil, nil end
    vim.api.nvim_set_hl(0, group, attrs)
  end
  for _, name in ipairs(groups) do clear(name) end
  if config.floats then for _, name in ipairs(floats) do clear(name) end end
  if config.sidebars then for _, name in ipairs(sidebars) do clear(name) end end
end

function M.setup()
  local group = vim.api.nvim_create_augroup("OwnedTransparency", { clear = true })
  vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = M.apply })
  vim.api.nvim_create_autocmd("User", {
    group = group, pattern = "LazyLoad",
    callback = function(args)
      if args.data == "nvim-tree.lua" or args.data == "fzf-lua" or args.data == "mason.nvim" then
        M.apply()
        require("config.highlights").apply()
      end
    end,
  })
  vim.api.nvim_create_user_command("TransparencyToggle", function()
    local config = require "config.transparency"
    config.enabled = not config.enabled
    require("config.theme_loader").apply(require("config.theme_loader").current())
    vim.notify("Transparency " .. (config.enabled and "on" or "off"))
  end, { desc = "Toggle transparent editor/pane backgrounds without changing the theme" })
  M.apply()
end

return M
