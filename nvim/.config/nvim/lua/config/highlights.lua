-- User overrides only; reapply after any :colorscheme, never reload a theme.
local M = {}

M.groups = {
  -- Comment = { italic = true },
  -- Normal = { bg = "NONE" },
}

function M.apply()
  local color = require "ui.color"
  local normal = color.get "Normal"
  local bg = normal.bg or (vim.o.background == "light" and 0xffffff or 0x1e222a)
  local fg = normal.fg or (vim.o.background == "light" and 0x202020 or 0xd0d0d0)
  local accent = color.get("Function").fg or fg
  local search = color.mix(accent, bg, 0.35)
  vim.api.nvim_set_hl(0, "Search", { bg = search, fg = color.text_on(search) })
  vim.api.nvim_set_hl(0, "IncSearch", { bg = accent, fg = color.text_on(accent), bold = true })
  vim.api.nvim_set_hl(0, "CurSearch", { link = "IncSearch" })
  vim.api.nvim_set_hl(0, "CursorLine", { bg = color.mix(fg, bg, 0.06) })
  for group, attrs in pairs(M.groups) do
    -- Merge partial overrides without discarding the theme's other attributes.
    local base = attrs.link and {} or vim.api.nvim_get_hl(0, { name = group, link = false })
    base.default = nil -- don't inherit a plugin's "only set if absent" flag
    vim.api.nvim_set_hl(0, group, vim.tbl_extend("force", base, attrs))
  end
end

function M.setup()
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("UserHighlights", { clear = true }),
    callback = M.apply,
  })
  M.apply()
end

return M
