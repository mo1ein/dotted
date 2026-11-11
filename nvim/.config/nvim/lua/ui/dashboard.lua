-- Small startup dashboard using existing actions; never replaces an open file.
local M = {}
local namespace = vim.api.nvim_create_namespace "OwnedDashboard"
local hover_namespace = vim.api.nvim_create_namespace "OwnedDashboardHover"
local actions = {
  { "f", "Find file", function() require("fzf-lua").files() end },
  { "r", "Recent files", function() require("fzf-lua").oldfiles() end },
  { "s", "Search project", function() require("fzf-lua").live_grep() end },
  { "n", "New buffer", function() vim.cmd.enew(); vim.bo.buflisted = true; vim.cmd.startinsert() end },
  { "k", "Keymap table", function() vim.cmd.Keymaps() end },
  { "c", "Cheatsheet", function() vim.cmd.Cheatsheet() end },
  { "t", "Choose theme", function() vim.cmd.Theme() end },
  { "p", "Plugins", function() vim.cmd.Lazy() end },
  { "q", "Quit", function() vim.cmd.quit() end },
}

function M.open()
  local saved = {}
  for _, option in ipairs { "number", "relativenumber", "cursorline", "signcolumn", "wrap" } do saved[option] = vim.wo[option] end
  if vim.bo.modified then vim.cmd.new() else vim.cmd.enew() end
  local buf, win = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
  vim.bo[buf].buftype, vim.bo[buf].bufhidden, vim.bo[buf].buflisted = "nofile", "wipe", false
  vim.bo[buf].filetype = "dashboard"
  vim.wo[win].number, vim.wo[win].relativenumber, vim.wo[win].cursorline = false, false, false
  vim.wo[win].signcolumn, vim.wo[win].wrap = "no", false
  local rows, buttons, hovered = {}, {}, nil
  local function render()
    if not vim.api.nvim_win_is_valid(win) or not vim.api.nvim_buf_is_valid(buf) then return end
    local w, h = vim.api.nvim_win_get_width(win), vim.api.nvim_win_get_height(win)
    local lines, highlights = {}, {}
    local function add(text, group)
      lines[#lines + 1] = string.rep(" ", math.max(0, math.floor((w - vim.fn.strdisplaywidth(text)) / 2))) .. text
      if group then highlights[#highlights + 1] = { #lines - 1, group } end
    end
    for _ = 1, math.max(0, math.floor((h - 23) / 2)) do add("") end
    add("d o t t e d", "Title")
    add("NEOVIM WORKSPACE", "Comment")
    add("")
    add(vim.fn.fnamemodify(vim.fn.getcwd(), ":~"), "Directory")
    add("")
    rows = {}
    buttons = {}
    for _, action in ipairs(actions) do
      add(("[%s]  %-18s"):format(action[1], action[2]), "Special")
      rows[#lines] = action[3]
      buttons[#lines] = { start = assert(lines[#lines]:find("[", 1, true)) - 1, finish = #lines[#lines] }
    end
    add("")
    add("Space: leader · /: search · Enter: open", "Comment")
    add("Neovim " .. tostring(vim.version()), "Comment")
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
    for _, mark in ipairs(highlights) do
      vim.api.nvim_buf_set_extmark(buf, namespace, mark[1], 0, { end_col = #lines[mark[1] + 1], hl_group = mark[2] })
    end
    vim.bo[buf].modifiable = false
  end
  render()
  local function hit(mouse)
    local button = buttons[mouse.line]
    return mouse.winid == win and button and mouse.column > button.start and mouse.column <= button.finish and mouse.line or nil
  end
  local function clear_hover()
    hovered = nil
    if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_clear_namespace(buf, hover_namespace, 0, -1) end
  end
  local detach_hover = require("ui.statusline_hover").register(win, function(mouse)
    local row = hit(mouse)
    if not row then return end
    if hovered ~= row then
      clear_hover()
      hovered = row
      vim.api.nvim_buf_set_extmark(buf, hover_namespace, row - 1, buttons[row].start, {
        end_col = buttons[row].finish, hl_group = "DottedBreadcrumbSelection", priority = 200,
      })
    end
    return row
  end, clear_hover)
  for _, action in ipairs(actions) do vim.keymap.set("n", action[1], action[3], { buffer = buf, desc = action[2], nowait = true }) end
  vim.keymap.set("n", "<CR>", function()
    local action = rows[hovered or vim.api.nvim_win_get_cursor(win)[1]]
    if action then action() end
  end, { buffer = buf })
  vim.keymap.set("n", "<LeftMouse>", function()
    local row = hit(vim.fn.getmousepos())
    if row then rows[row]() end
  end, { buffer = buf, silent = true, nowait = true })
  local resize = vim.api.nvim_create_autocmd("VimResized", { callback = render })
  vim.api.nvim_create_autocmd("BufWinLeave", { buffer = buf, once = true, callback = function()
    if vim.api.nvim_win_is_valid(win) then for option, value in pairs(saved) do vim.wo[win][option] = value end end
  end })
  vim.api.nvim_create_autocmd("BufWipeout", { buffer = buf, once = true, callback = function()
    detach_hover()
    pcall(vim.api.nvim_del_autocmd, resize)
  end })
  return { buf = buf, win = win }
end

function M.setup()
  vim.api.nvim_create_user_command("Dashboard", M.open, { desc = "Open the owned startup dashboard" })
  local stdin = false
  local group = vim.api.nvim_create_augroup("OwnedDashboardStartup", { clear = true })
  vim.api.nvim_create_autocmd("StdinReadPre", { group = group, callback = function() stdin = true end })
  vim.api.nvim_create_autocmd("VimEnter", { group = group, once = true, callback = function()
    vim.schedule(function()
      if not stdin and vim.fn.argc() == 0 and #vim.api.nvim_list_uis() > 0 and vim.bo.buftype == ""
        and vim.api.nvim_buf_get_name(0) == "" and not vim.bo.modified and vim.api.nvim_buf_line_count(0) == 1
        and vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] == "" then M.open() end
    end)
  end })
end

return M
