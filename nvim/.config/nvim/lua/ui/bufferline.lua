-- Native clickable buffer tabs; no distribution, new plugin, or forced deletions.
local M = {}
local targets = { buffers = {}, tabs = {} }
function M.hover_targets() return targets end
local function escape(text) return text:gsub("%%", "%%%%"):gsub("[%c]", " ") end

function M.highlights()
  local colors = require "ui.color"
  local normal = colors.get "Normal"
  local canvas = normal.bg or colors.get("NormalFloat").bg or (vim.o.background == "light" and 0xfafafa or 0x1e222a)
  local foreground = normal.fg or (vim.o.background == "light" and 0x202020 or 0xd0d0d0)
  local accent = colors.get("DottedSt_NormalMode").bg or colors.get("Function").fg or foreground
  local panel = colors.mix(foreground, canvas, 0.07)
  vim.api.nvim_set_hl(0, "DottedBufActive", { fg = colors.text_on(accent), bg = accent, bold = true })
  vim.api.nvim_set_hl(0, "DottedBufInactive", { fg = colors.readable(foreground, panel), bg = panel })
  vim.api.nvim_set_hl(0, "DottedBufNumber", { fg = colors.readable(accent, panel), bg = panel, bold = true })
  vim.api.nvim_set_hl(0, "DottedBufNumberActive", { fg = colors.text_on(accent), bg = accent, bold = true })
  vim.api.nvim_set_hl(0, "DottedBufFill", {
    fg = colors.readable(colors.get("Comment").fg or foreground, canvas),
    bg = require("config.transparency").enabled and "NONE" or canvas,
  })
  for group, target in pairs {
    DottedDashboardButton = "DottedBufFill", DottedDashboardButtonHover = "DottedBreadcrumbSelection",
    DottedBufHover = "DottedBreadcrumbSelection", DottedBufNumberHover = "DottedHoverNumber",
    DottedBufClose = "DottedBufNumber", DottedBufCloseActive = "DottedBufNumberActive",
    DottedBufCloseHover = "DottedBreadcrumbSelection", DottedBufPad = "DottedBufNumber", DottedBufPadActive = "DottedBufNumberActive",
    DottedTabPageActive = "DottedBufActive", DottedTabPageInactive = "DottedBufInactive", DottedTabPageHover = "DottedBreadcrumbSelection",
  } do vim.api.nvim_set_hl(0, group, { link = target }) end
end

function M.render()
  local buffers, current = require("ui.buffers").list(), vim.api.nvim_get_current_buf()
  if not vim.tbl_contains(buffers, current) then current = require("ui.buffers").recent()[1] end
  local labels, index = {}, 1
  for i, buf in ipairs(buffers) do
    local name = vim.api.nvim_buf_get_name(buf)
    local label = name == "" and "[New]" or vim.fn.fnamemodify(name, ":t")
    for _, other in ipairs(buffers) do
      if other ~= buf and name ~= "" and vim.fn.fnamemodify(vim.api.nvim_buf_get_name(other), ":t") == label then
        label = vim.fn.fnamemodify(name, ":h:t") .. "/" .. label
        break
      end
    end
    label = vim.fn.strcharpart(label, 0, 28) .. (vim.bo[buf].modified and " ●" or "")
    labels[i] = label .. " [" .. i .. "]"
    if buf == current then index = i end
  end
  local selected, used, budget = { index }, 0, math.max(10, vim.o.columns - 78)
  if #buffers == 0 then selected = {} else used = vim.fn.strdisplaywidth(labels[index]) + 8 end
  local left, right = index - 1, index + 1
  while left >= 1 or right <= #buffers do
    local candidate = right <= #buffers and right or left
    local size = vim.fn.strdisplaywidth(labels[candidate]) + 8
    if used + size > budget then break end
    used = used + size
    if candidate == right then selected[#selected + 1] = right; right = right + 1
    else table.insert(selected, 1, left); left = left - 1 end
  end
  local hover = require "ui.statusline_hover"
  targets = { buffers = {}, tabs = {} }
  local out = { ("%%#%s#%%0@v:lua.DottedDashboardClick@  dotted  %%X%%#DottedBufFill#")
    :format(hover.dashboard() and "DottedDashboardButtonHover" or "DottedDashboardButton") }
  if #selected > 0 and selected[1] > 1 then out[#out + 1] = " ‹ " end
  for _, i in ipairs(selected) do
    local buf = buffers[i]
    local active = buf == current
    targets.buffers[#targets.buffers + 1] = buf
    local label = labels[i]:gsub(" %[%d+%]$", "")
    out[#out + 1] = ("%%#%s#%%%d@v:lua.DottedBufferClick@ %s %%#%s#[%d] %%X%%#%s#%%%d@v:lua.DottedBufferClose@ × %%X%%#%s#")
      :format(hover.buffer(buf) and "DottedBufHover" or active and "DottedBufActive" or "DottedBufInactive", buf, escape(label),
        hover.buffer(buf) and "DottedBufNumberHover" or active and "DottedBufNumberActive" or "DottedBufNumber", i,
        hover.buffer_close(buf) and "DottedBufCloseHover" or active and "DottedBufCloseActive" or "DottedBufClose", buf,
        active and "DottedBufPadActive" or "DottedBufPad")
  end
  if #selected > 0 and selected[#selected] < #buffers then out[#out + 1] = " › " end
  out[#out + 1] = "%#DottedBufFill#%="
  out[#out + 1] = require("ui.run_toolbar").render()
  out[#out + 1] = "%0@v:lua.DottedThemeClick@ " .. (vim.o.background == "light" and "☾ Dark" or "☀ Light") .. " %X"
  if #vim.api.nvim_list_tabpages() > 1 then
    for i, tab in ipairs(vim.api.nvim_list_tabpages()) do
      targets.tabs[#targets.tabs + 1] = tab
      out[#out + 1] = ("%%#%s#%%%dT %d %%T"):format(hover.tabpage(tab) and "DottedTabPageHover"
        or tab == vim.api.nvim_get_current_tabpage() and "DottedTabPageActive" or "DottedTabPageInactive", i, i)
    end
  end
  return table.concat(out)
end

function M.setup()
  require("ui.run_toolbar").setup()
  _G.DottedRunClick = function()
    local target = require("util.run").capture()
    vim.schedule(function() require("util.run").file(target) end)
  end
  _G.DottedProjectRunClick = function()
    local target = require("util.run").capture()
    vim.schedule(function() require("util.run").project(target) end)
  end
  _G.DottedThemeClick = function() vim.schedule(function()
    require("config.theme_loader").apply(vim.o.background == "light" and "dotted-onedark" or "zed-gruvbox-light-soft", true)
    vim.cmd.redrawtabline()
  end) end
  _G.DottedBufferClose = function(buf)
    if vim.api.nvim_buf_is_valid(buf) then
      if vim.bo[buf].modified then vim.notify("Save or discard this buffer's changes before closing it", vim.log.levels.WARN); return end
      local ok, err = pcall(vim.cmd.bdelete, { args = { tostring(buf) } })
      if not ok then vim.notify(tostring(err), vim.log.levels.WARN) end
    end
  end
  _G.DottedBufferClick = function(buf, _, button)
    if button == "m" then return _G.DottedBufferClose(buf) end
    if vim.api.nvim_buf_is_valid(buf) then require("ui.buffers").focus(buf) end
  end
  _G.DottedDashboardClick = function() require("ui.dashboard").open() end
  vim.o.showtabline = 2
  vim.o.tabline = "%!v:lua.require('ui.bufferline').render()"
  local group = vim.api.nvim_create_augroup("OwnedBufferline", { clear = true })
  vim.api.nvim_create_autocmd({ "BufAdd", "BufDelete", "BufEnter", "BufModifiedSet", "TabEnter" }, {
    group = group,
    callback = function() vim.cmd.redrawtabline() end,
  })
  vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = M.highlights })
  M.highlights()
end

return M
