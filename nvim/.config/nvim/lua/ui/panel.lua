-- The same geometry and theme roles as the file finder; no UI plugin required.
local M = {}

function M.options(title, height)
  local config = require("config.ui").panel
  local w = math.max(1, math.min(vim.o.columns - 4, math.floor(vim.o.columns * config.width)))
  local h = math.max(1, math.min(vim.o.lines - 4, math.floor(vim.o.lines * (height or config.height))))
  return {
    relative = "editor", style = "minimal", border = config.border,
    width = w, height = h, title = " " .. title .. " ", title_pos = "center",
    row = math.max(0, math.floor((vim.o.lines - h) / 2) - 1),
    col = math.max(0, math.floor((vim.o.columns - w) / 2)),
  }
end

function M.finder()
  local config = require("config.ui").panel
  return {
    winopts = { width = config.width, height = config.height, border = config.border },
    hls = { normal = "NormalFloat", border = "FloatBorder", title = "Title", header = "Comment", prompt = "Special" },
  }
end

-- Small top-right search widget; the large preview is available on demand.
function M.replace_options(title, scope, expanded, origin)
  if expanded then
    local options = M.options(title, scope == "buffer" and 0.50 or nil)
    options.footer, options.footer_pos = " Alt-e compact ", "right"
    return options
  end
  local config = require "config.ui"
  origin = origin or require("ui.buffers").source_win()
  local anchored = origin and vim.api.nvim_win_is_valid(origin)
  local columns = anchored and vim.api.nvim_win_get_width(origin) or vim.o.columns
  local w = math.max(1, math.min(config.replace.width, columns - 2))
  local h = math.max(1, math.min(scope == "buffer" and config.replace.buffer_height or config.replace.project_height, vim.o.lines - 5))
  local tabline = vim.o.showtabline == 2 or (vim.o.showtabline == 1 and #vim.api.nvim_list_tabpages() > 1)
  return {
    relative = anchored and "win" or "editor", win = anchored and origin or nil, style = "minimal", border = config.panel.border,
    width = w, height = h, row = anchored and 0 or (tabline and 1 or 0), col = math.max(0, columns - w - 2),
    title = " " .. title .. " ", title_pos = "center",
    footer = " Alt-e expand ", footer_pos = "right",
  }
end

return M
