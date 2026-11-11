-- Preserve the former Git gutter/number colors, derived from the active palette.
local M = {}

function M.apply()
  local function fg(group) return require("ui.color").get(group).fg end
  local add = fg("DiffAdd") or fg("Added") or 0x73bd79
  local change = fg("DiffChange") or fg("Changed") or 0x70aeff
  local delete = fg("DiffDelete") or fg("Removed") or 0x6f737a
  local muted = fg("Comment") or 0x636d83
  local function set(group, attrs) vim.api.nvim_set_hl(0, group, attrs) end
  for suffix, color in pairs {
    Add = add, Change = change, Delete = delete,
    Changedelete = change, Topdelete = delete, Untracked = muted,
    AddNr = add, ChangeNr = change, DeleteNr = delete,
  } do set("GitSigns" .. suffix, { fg = color }) end
  for suffix, group in pairs { AddLn = "DiffAdd", ChangeLn = "DiffChange" } do
    local color = fg(group)
    if color then set("GitSigns" .. suffix, { bg = color, nocombine = true }) end
  end
  set("GitSignsCurrentLineBlame", { fg = muted, italic = true })
  -- Palette adaptation must never override explicit user highlight choices.
  require("config.highlights").apply()
end

function M.setup()
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("OwnedGitColors", { clear = true }),
    -- Run after the provider and Gitsigns finish refreshing their highlights.
    callback = function() vim.schedule(M.apply) end,
  })
  M.apply()
end

return M
