-- One file-buffer list for numbered tabs and the MRU switcher.
local M = {}
local touched, clock, last_windows = {}, 0, {}
local editor_options, last_options = {}, nil
local option_names = {
  "number", "relativenumber", "signcolumn", "statuscolumn", "winbar", "winhighlight", "foldcolumn",
  "foldmethod", "foldenable", "wrap", "spell", "list", "cursorline", "cursorlineopt", "scrolloff", "sidescrolloff", "winblend",
}
M.suspend_touch = false

local function restore_editor(win, defaults)
  vim.w[win].dotted_tool = nil
  for _, name in ipairs(option_names) do
    local value = defaults[name]
    if value == nil then value = vim.go[name] end
    vim.wo[win][name] = value
  end
  vim.wo[win].winfixheight, vim.wo[win].winfixwidth = false, false
end

local function remember(win, normalize)
  if not win or not vim.api.nvim_win_is_valid(win) then return end
  local buf, tab = vim.api.nvim_win_get_buf(win), vim.api.nvim_win_get_tabpage(win)
  if not vim.bo[buf].buflisted or vim.bo[buf].buftype ~= "" or vim.api.nvim_win_get_config(win).relative ~= "" then return end
  if vim.wo[win].winbar == "%!v:lua.require('ui.tools').header()"
    or vim.wo[win].winhighlight == "Normal:NormalFloat,EndOfBuffer:NormalFloat,WinBar:DottedToolInactive,WinBarNC:DottedToolInactive" then
    -- A tab/split created from a tool can inherit its local options before its
    -- buffer is entered. Neovim can clear winbar but retain winhighlight.
    -- Normalize only our exact owned chrome, not other bars or user styling.
    if not normalize then return end -- source_win() is also used during redraw.
    restore_editor(win, editor_options[tab] or last_options or {})
  end
  if vim.w[win].dotted_tool then return end
  local values = {}
  for _, name in ipairs(option_names) do values[name] = vim.wo[win][name] end
  editor_options[tab], last_windows[tab] = values, win
  last_options = vim.deepcopy(values)
end

function M.touch(buf)
  if not M.suspend_touch and vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted and vim.bo[buf].buftype == "" then
    clock = clock + 1
    touched[buf] = clock
  end
end

function M.list()
  local result = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].buflisted and vim.bo[buf].buftype == "" then result[#result + 1] = buf end
  end
  return result
end

function M.recent()
  local result = M.list()
  table.sort(result, function(a, b)
    if (touched[a] or 0) == (touched[b] or 0) then return a < b end
    return (touched[a] or 0) > (touched[b] or 0)
  end)
  return result
end

function M.is_source(win)
  if not win or not vim.api.nvim_win_is_valid(win) or vim.w[win].dotted_tool then return false end
  local buf = vim.api.nvim_win_get_buf(win)
  return vim.bo[buf].buflisted and vim.bo[buf].buftype == "" and vim.api.nvim_win_get_config(win).relative == ""
end

function M.source_win()
  local current, tab = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_tabpage()
  remember(current)
  if M.is_source(current) then return current end
  local previous = last_windows[tab]
  if M.is_source(previous) and vim.api.nvim_win_get_tabpage(previous) == tab then return previous end
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if M.is_source(win) then last_windows[tab] = win; return win end
  end
end

function M.focus(buf)
  if not vim.api.nvim_buf_is_valid(buf) then return end
  local win = M.source_win()
  if not win then
    local defaults = vim.deepcopy(editor_options[vim.api.nvim_get_current_tabpage()] or last_options or {})
    local anchor = vim.api.nvim_get_current_win()
    for _, candidate in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if vim.w[candidate].dotted_tool then anchor = candidate; break end
    end
    local side = vim.bo[vim.api.nvim_win_get_buf(anchor)].filetype == "NvimTree" and "right" or "above"
    win = vim.api.nvim_open_win(buf, true, { split = side, win = anchor })
    restore_editor(win, defaults)
  end
  vim.api.nvim_set_current_win(win)
  vim.api.nvim_win_set_buf(win, buf)
  remember(win, true)
end

function M.go(index)
  if not index or index < 1 or index % 1 ~= 0 then vim.notify("Buffer position must be a positive integer", vim.log.levels.WARN); return end
  local buf = M.list()[index]
  if not buf then vim.notify("No file buffer at position " .. index, vim.log.levels.INFO); return end
  M.focus(buf)
end

function M.setup()
  local group = vim.api.nvim_create_augroup("DottedFileBuffers", { clear = true })
  local function touch(args)
    M.touch(args.buf)
    remember(vim.api.nvim_get_current_win(), true)
  end
  vim.api.nvim_create_autocmd("BufEnter", { group = group, callback = touch })
  vim.api.nvim_create_autocmd("WinEnter", { group = group, callback = function() remember(vim.api.nvim_get_current_win(), true) end })
  vim.api.nvim_create_autocmd("WinLeave", { group = group, callback = function() remember(vim.api.nvim_get_current_win(), true) end })
  vim.api.nvim_create_autocmd("TabClosed", { group = group, callback = function()
    for tab in pairs(last_windows) do if not vim.api.nvim_tabpage_is_valid(tab) then last_windows[tab], editor_options[tab] = nil, nil end end
  end })
  vim.api.nvim_create_autocmd("BufDelete", { group = group, callback = function(args) touched[args.buf] = nil end })
  touch { buf = vim.api.nvim_get_current_buf() }
  vim.api.nvim_create_user_command("BufferGo", function(args) M.go(tonumber(args.args)) end, {
    nargs = 1, desc = "Go to a file buffer by its tabline position",
    complete = function() return #M.list() == 0 and {} or vim.tbl_map(tostring, vim.fn.range(1, #M.list())) end,
  })
end

return M
