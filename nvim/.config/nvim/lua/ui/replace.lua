-- Themed in-file replacement (unsaved buffers) and project replacement (ripgrep).
local M = {}
local engine = require "util.replace"
local labels = vim.api.nvim_create_namespace "OwnedReplacePanel"
local sessions, windows, projects = {}, {}, {}
function M.current(origin) return origin and sessions[origin] or windows[vim.api.nvim_get_current_win()] end
function M.close(session)
  session = type(session) == "table" and session or session and sessions[session] or M.current()
  if not session or sessions[session.origin] ~= session then return end
  sessions[session.origin], windows[session.win] = nil, nil
  local focused = vim.api.nvim_get_current_win() == session.win
  if focused then vim.cmd.stopinsert() end
  session.timer:stop()
  if not session.timer:is_closing() then session.timer:close() end
  if session.group then pcall(vim.api.nvim_del_augroup_by_id, session.group) end
  if vim.api.nvim_buf_is_valid(session.target) then vim.api.nvim_buf_clear_namespace(session.target, session.namespace, 0, -1) end
  if vim.api.nvim_win_is_valid(session.win) then vim.api.nvim_win_close(session.win, true) end
  if focused and vim.api.nvim_win_is_valid(session.origin) then vim.api.nvim_set_current_win(session.origin) end
end
_G.DottedReplaceHeader = function()
  local win = tonumber(vim.g.statusline_winid) or vim.api.nvim_get_current_win()
  return windows[win] and windows[win].header() or ""
end
_G.DottedReplaceClick = function(id)
  local session = windows[vim.fn.getmousepos().winid] or windows[vim.api.nvim_get_current_win()]
  if session then session.click(id) end
end
_G.DottedProjectReplaceHeader = function()
  local win = tonumber(vim.g.statusline_winid) or vim.api.nvim_get_current_win()
  return projects[win] and projects[win].header() or ""
end
_G.DottedProjectReplaceClick = function(id)
  local project = projects[vim.fn.getmousepos().winid] or projects[vim.api.nvim_get_current_win()]
  if project then project.click(id) end
end

function M.buffer(opts)
  opts = opts or {}
  local current = M.current()
  if current then return current end
  local target, origin = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
  if vim.bo[target].buftype ~= "" then vim.notify("Open a file buffer first", vim.log.levels.WARN); return end
  local existing = sessions[origin]
  if existing and existing.target == target and vim.api.nvim_win_is_valid(existing.win) then
    vim.api.nvim_set_current_win(existing.win)
    return existing
  end
  if existing then M.close(existing) end
  local namespace = vim.api.nvim_create_namespace("OwnedReplaceMatches:" .. origin)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden, vim.bo[buf].filetype = "wipe", "dotted-replace"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { opts.search or "", opts.replacement or "" })
  local win = vim.api.nvim_open_win(buf, true, require("ui.panel").replace_options("Replace · buffer", "buffer", false, origin))
  vim.wo[win].winhighlight = "Normal:NormalFloat"
  vim.wo[win].wrap, vim.wo[win].cursorline = false, true
  local session = { buf = buf, win = win, target = target, origin = origin, timer = assert(vim.uv.new_timer()),
    options = { regex = opts.regex or false, case_sensitive = opts.case_sensitive or false, word = opts.word or false }, index = 1 }
  session.namespace = namespace
  sessions[origin], windows[win] = session, session
  local function values()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    return lines[1] or "", lines[2] or ""
  end
  function session.refresh()
    if sessions[origin] ~= session or not vim.api.nvim_buf_is_valid(target) then return end
    local search, replacement = values()
    local matches, err = engine.scan(target, search, session.options)
    session.matches = matches or {}
    session.index = math.max(1, math.min(session.index, #session.matches))
    vim.api.nvim_buf_clear_namespace(buf, labels, 0, -1)
    vim.api.nvim_buf_clear_namespace(target, namespace, 0, -1)
    local function label(row, text)
      -- Inline labels remain visible at topline; virtual lines above row 0 do not.
      vim.api.nvim_buf_set_extmark(buf, labels, row, 0,
        { virt_text = { { text .. " › ", "Special" } }, virt_text_pos = "inline", right_gravity = false })
    end
    label(0, " Search")
    label(1, " Replace with")
    local preview = {
      { { (" %s · %s · %s · %s"):format(err and "Invalid regex" or ((session.message or "") .. #session.matches .. " matches"),
        session.options.regex and "Regex" or "Literal", session.options.case_sensitive and "Case sensitive" or "Ignore case",
        session.options.word and "Word" or "Any"), err and "DiagnosticError" or "Title" } },
      { { " Tab fields · Enter: next / replace · Ctrl-s: all", "Comment" } },
    }
    if session.expanded then
      preview[#preview + 1] = { { " Alt-r regex · Alt-c case · Alt-w word · q/Esc close", "Comment" } }
      preview[#preview + 1] = { { " Changes stay unsaved · u in the file undoes replacements", "Comment" } }
      preview[#preview + 1] = { { "", "Comment" } }
      if err then preview[#preview + 1] = { { err:gsub("\n", " "), "DiagnosticError" } } end
    end
    local shown, preview_count = {}, 0
    for i, match in ipairs(session.matches) do
      if i <= 5000 then
        vim.api.nvim_buf_set_extmark(target, namespace, match.row, match.start,
          { end_col = match.finish, hl_group = i == session.index and "IncSearch" or "Search", priority = 250 })
      end
      if session.expanded and i >= session.index and not shown[match.row] and preview_count < 5 then
        shown[match.row], preview_count = true, preview_count + 1
        local line = vim.api.nvim_buf_get_lines(target, match.row, match.row + 1, false)[1]
        preview[#preview + 1] = { { (" %s %4d │ %s"):format(i == session.index and "▶" or " ", match.row + 1,
          vim.fn.strcharpart(line, 0, 120)), i == session.index and "Special" or "NormalFloat" } }
        local updated = engine.preview(line, search, replacement, session.options)
        if updated and updated ~= line then preview[#preview + 1] = { { "        → " .. vim.fn.strcharpart(updated, 0, 120), "String" } } end
      end
    end
    vim.api.nvim_buf_set_extmark(buf, labels, 1, 0, { virt_lines = preview })
    session.error = err
  end
  function session.apply(all)
    if not vim.api.nvim_buf_is_valid(target) then M.close(session); return end
    local search, replacement = values()
    if vim.api.nvim_buf_line_count(buf) ~= 2 then
      vim.notify("Use two input lines: search, then replacement. Multiline input isn't supported here.", vim.log.levels.WARN)
      return nil, "Invalid input fields"
    end
    local count, err = engine.apply(target, search, replacement, session.options, not all and session.index or nil)
    if not count then vim.notify(tostring(err), vim.log.levels.WARN) end
    session.message = count and ("Replaced " .. count .. " · ") or nil
    for _, other in pairs(sessions) do if other.target == target then other.refresh() end end
    return count, err
  end
  local function navigate(delta)
    session.refresh()
    if #session.matches == 0 then return end
    session.index = (session.index - 1 + delta) % #session.matches + 1
    local match = session.matches[session.index]
    if vim.api.nvim_win_is_valid(origin) and vim.api.nvim_win_get_buf(origin) == target then
      vim.api.nvim_win_set_cursor(origin, { match.row + 1, match.start })
      vim.api.nvim_win_call(origin, function() vim.cmd "normal! zz" end)
    end
    session.refresh()
  end
  local function map(modes, key, callback) vim.keymap.set(modes, key, callback, { buffer = buf, silent = true, nowait = true }) end
  map({ "n", "i" }, "<M-e>", function()
    session.expanded = not session.expanded
    vim.api.nvim_win_set_config(win, require("ui.panel").replace_options("Replace · buffer", "buffer", session.expanded, origin))
    session.refresh()
  end)
  for _, key in ipairs { "<Tab>", "<S-Tab>" } do
    map({ "n", "i" }, key, function() vim.api.nvim_win_set_cursor(win, { vim.api.nvim_win_get_cursor(win)[1] == 1 and 2 or 1, 0 }) end)
  end
  for _, key in ipairs { "o", "O" } do
    map("n", key, function() vim.api.nvim_win_set_cursor(win, { 2, 0 }); vim.cmd.startinsert() end)
  end
  map("n", "dd", function()
    local row = vim.api.nvim_win_get_cursor(win)[1]
    vim.api.nvim_buf_set_lines(buf, row - 1, row, false, { "" }); session.refresh()
  end)
  vim.keymap.set("i", "<BS>", function() return vim.fn.col "." == 1 and "" or "<BS>" end,
    { buffer = buf, expr = true, silent = true })
  map({ "n", "i" }, "<CR>", function()
    if vim.api.nvim_win_get_cursor(win)[1] == 2 then session.apply(false) else navigate(1) end
  end)
  map({ "n", "i" }, "<C-CR>", function() session.apply(true) end)
  map({ "n", "i" }, "<C-n>", function() navigate(1) end)
  map({ "n", "i" }, "<C-p>", function() navigate(-1) end)
  map({ "n", "i" }, "<C-s>", function() session.apply(true) end)
  map({ "n", "i" }, "<C-g>", function() session.apply(false) end)
  for key, option in pairs { ["<M-r>"] = "regex", ["<M-c>"] = "case_sensitive", ["<M-w>"] = "word" } do
    map({ "n", "i" }, key, function() session.options[option] = not session.options[option]; session.refresh() end)
  end
  map("n", "q", function() M.close(session) end)
  map("n", "<Esc>", function() M.close(session) end)
  local group = vim.api.nvim_create_augroup("OwnedReplacePanel" .. origin, { clear = true })
  session.group = group
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, { group = group, buffer = buf, callback = function()
    session.message = nil
    session.timer:stop()
    session.timer:start(100, 0, vim.schedule_wrap(session.refresh))
  end })
  vim.api.nvim_create_autocmd("VimResized", { group = group, callback = function()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_set_config(win, require("ui.panel").replace_options("Replace · buffer", "buffer", session.expanded, origin))
    end
  end })
  vim.api.nvim_create_autocmd("BufWipeout", { group = group, buffer = buf, once = true, callback = function()
    if sessions[origin] == session then M.close(session) end
    pcall(vim.api.nvim_del_augroup_by_id, group)
  end })
  local function expand()
    session.expanded = not session.expanded
    vim.api.nvim_win_set_config(win, require("ui.panel").replace_options("Replace · buffer", "buffer", session.expanded, origin))
    session.refresh()
  end
  function session.header()
    local out = {}
    local buttons = { ".*", "Aa", "[w]", "↑", "↓", "󰑕", "󰒝", "󰘖", "×" }
    for id, icon in ipairs(buttons) do
      local option = ({ "regex", "case_sensitive", "word" })[id]
      out[#out + 1] = require("ui.controls").button("replace", id, icon, "DottedReplaceClick", option and session.options[option])
    end
    return table.concat(out)
  end
  session.click = function(id) vim.schedule(function()
    if sessions[origin] ~= session then return end
    if vim.api.nvim_get_current_win() ~= win then vim.api.nvim_set_current_win(win) end
    local option = ({ "regex", "case_sensitive", "word" })[id]
    if option then session.options[option] = not session.options[option]; session.refresh()
    elseif id == 4 then navigate(-1) elseif id == 5 then navigate(1)
    elseif id == 6 then session.apply(false) elseif id == 7 then session.apply(true)
    elseif id == 8 then expand() elseif id == 9 then M.close(session) end
    vim.cmd.redrawstatus()
  end) end
  vim.wo[win].winbar = "%!v:lua.DottedReplaceHeader()"
  require("ui.controls").attach_winbar(buf, win, "replace", function(id) session.click(id) end)
  vim.api.nvim_create_autocmd("WinResized", { group = group, callback = function()
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_is_valid(origin) then
      vim.api.nvim_win_set_config(win, require("ui.panel").replace_options("Replace · buffer", "buffer", session.expanded, origin))
    end
  end })
  vim.api.nvim_create_autocmd("WinClosed", { group = group, pattern = tostring(origin), once = true,
    callback = function() vim.schedule(function() if sessions[origin] == session then M.close(session) end end) end })
  vim.api.nvim_create_autocmd("BufEnter", { group = group, callback = function(args)
    if vim.api.nvim_get_current_win() == origin and args.buf ~= target then M.close(session) end
  end })
  session.refresh()
  if opts.start_in_insert ~= false then vim.cmd.startinsert() end
  return session
end

function M.project_window()
  local origin = require("ui.buffers").source_win()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  local win = vim.api.nvim_open_win(buf, true, require("ui.panel").replace_options("Replace · project", "project", false, origin))
  vim.wo[win].winhighlight = "Normal:NormalFloat"
  -- grug-far swaps our scratch buffer for its own after window creation returns.
  -- Bind there so the underlying :GrugFar command also supports expansion.
  vim.schedule(function()
    if not vim.api.nvim_win_is_valid(win) then return end
    local project_buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[project_buf].filetype ~= "grug-far" then return end
    vim.keymap.set({ "n", "i" }, "<M-e>", function()
      vim.w[win].dotted_replace_expanded = not vim.w[win].dotted_replace_expanded
      vim.api.nvim_win_set_config(win, require("ui.panel").replace_options("Replace · project", "project", vim.w[win].dotted_replace_expanded, origin))
    end, { buffer = project_buf, desc = "Toggle compact / expanded replacement panel" })
  end)
  local resize = vim.api.nvim_create_autocmd("VimResized", { callback = function()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_set_config(win, require("ui.panel").replace_options("Replace · project", "project", vim.w[win].dotted_replace_expanded, origin))
    end
  end })
  vim.api.nvim_create_autocmd("WinClosed", { pattern = tostring(win), once = true, callback = function()
    pcall(vim.api.nvim_del_autocmd, resize)
  end })
  return win
end

function M.project(opts)
  opts = opts or {}
  local origin = require("ui.buffers").source_win()
  local root = vim.fs.normalize(opts.root or vim.fs.root(0, ".git") or vim.fs.root(0, { "go.mod", "package.json" }) or vim.fn.getcwd())
  if #root > 1 then root = root:gsub("/$", "") end
  root = vim.uv.fs_realpath(root) or root
  local instance = require("grug-far").open {
    prefills = vim.tbl_extend("force", { paths = root:gsub(" ", "\\ "), flags = "--fixed-strings --ignore-case" }, opts.prefills or {}),
  }
  local buf = instance:get_buf()
  local flags = opts.prefills and opts.prefills.flags or "--fixed-strings --ignore-case"
  local modes = { not flags:find("--fixed-strings", 1, true), not flags:find("--ignore-case", 1, true), flags:find("--word-regexp", 1, true) ~= nil }
  local function toggle(id)
    local flag = ({ "--fixed-strings", "--ignore-case", "--word-regexp" })[id]
    local states = instance:toggle_flags { flag }
    modes[id] = id < 3 and not states[1] or id == 3 and states[1]
    vim.cmd.redrawstatus()
  end
  -- Never let a disk-wide replace silently overwrite edits in loaded buffers.
  local function apply(method)
    for _, candidate in ipairs(vim.api.nvim_list_bufs()) do
      local name = vim.api.nvim_buf_get_name(candidate)
      name = vim.uv.fs_realpath(name) or name
      if vim.bo[candidate].modified and name:sub(1, #root + 1) == root .. "/" and vim.bo[candidate].buftype == "" then
        vim.notify("Save modified project buffers before replacing on disk: " .. name, vim.log.levels.WARN)
        return false
      end
    end
    instance[method](instance)
    return true
  end
  for _, key in ipairs { "<CR>", "<C-CR>" } do
    vim.keymap.set({ "n", "i" }, key, function() apply("replace") end, { buffer = buf, desc = "Apply project replacement" })
  end
  vim.keymap.set({ "n", "i" }, "<C-s>", function() apply("replace") end, { buffer = buf, desc = "Replace across project (writes files)" })
  vim.keymap.set("n", "<C-g>", function() apply("sync_line") end, { buffer = buf, desc = "Replace current result line" })
  for key, id in pairs { ["<M-r>"] = 1, ["<M-c>"] = 2, ["<M-w>"] = 3 } do
    vim.keymap.set({ "n", "i" }, key, function() toggle(id) end, { buffer = buf })
  end
  local function close()
    if instance:get_status_info().status == "progress" then
      vim.notify("Replacement/search is still running. Wait, or press Ctrl-c to abort it.", vim.log.levels.INFO)
      return
    end
    instance:close()
  end
  for _, key in ipairs { "q", "<Esc>" } do vim.keymap.set("n", key, close, { buffer = buf, nowait = true }) end
  vim.keymap.set({ "n", "i" }, "<C-c>", function() instance:abort() end, { buffer = buf, desc = "Abort current search/replacement" })
  local win = vim.fn.bufwinid(buf)
  if win > 0 then
    local project = {}
    projects[win] = project
    project.header = function()
      local out = {}
      for id, label in ipairs { ".*", "Aa", "[w]", "󰒝", "󰘖", "×" } do
        out[#out + 1] = require("ui.controls").button("projectreplace", id, label, "DottedProjectReplaceClick", modes[id])
      end
      return table.concat(out)
    end
    project.click = function(id) vim.schedule(function()
      if not vim.api.nvim_win_is_valid(win) then return end
      local flag = ({ "--fixed-strings", "--ignore-case", "--word-regexp" })[id]
      if flag then toggle(id)
      elseif id == 4 then apply("replace")
      elseif id == 5 then
        vim.w[win].dotted_replace_expanded = not vim.w[win].dotted_replace_expanded
        vim.api.nvim_win_set_config(win, require("ui.panel").replace_options("Replace · project", "project", vim.w[win].dotted_replace_expanded, origin))
      elseif id == 6 then close() end
    end) end
    vim.api.nvim_create_autocmd("WinClosed", { pattern = tostring(win), once = true, callback = function() projects[win] = nil end })
    vim.wo[win].winbar = "%!v:lua.DottedProjectReplaceHeader()"
    require("ui.controls").attach_winbar(buf, win, "projectreplace", function(id) project.click(id) end)
  end
  return instance
end

function M.setup()
  vim.api.nvim_create_user_command("Replace", function() M.buffer() end, { desc = "Find and replace in the current buffer" })
  vim.api.nvim_create_user_command("ReplaceProject", function() M.project() end, { desc = "Preview and replace across the project" })
  local function highlights()
    for group, target in pairs {
      GrugFarInputLabel = "Title", GrugFarHelpHeaderKey = "Special", GrugFarResultsPath = "Directory",
      GrugFarResultsChangeIndicator = "DiagnosticWarn", GrugFarResultsRemoveIndicator = "DiagnosticError",
      GrugFarResultsAddIndicator = "String", GrugFarResultsMatch = "Search", GrugFarCurrentMatch = "IncSearch",
    } do vim.api.nvim_set_hl(0, group, { link = target }) end
    require("config.highlights").apply()
  end
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("OwnedSearchColors", { clear = true }), callback = highlights,
  })
  highlights()
end

return M
