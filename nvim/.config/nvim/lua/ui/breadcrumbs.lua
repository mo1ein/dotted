-- Bottom-statusline path navigation, with lazy one-directory dropdowns.
local M = {}
local cache = {}
local startup_root
local opened
local function escape(s) return s:gsub("[%c]", " "):gsub("%%", "%%%%") end

local function display_parts(buf)
  if opened and opened.buf == buf and opened.tab == vim.api.nvim_get_current_tabpage() then return opened.parts end
  return cache[buf]
end

local function contains(root, path) return root and vim.fs.relpath(root, path) ~= nil end
local function project_root(path, source)
  local cwd = vim.fn.getcwd(source and vim.fn.win_id2win(source) or 0)
  local root
  -- An explicitly opened directory or nested cwd is a project boundary even
  -- when its Git repository lives further up.
  for _, candidate in ipairs { cwd, startup_root or cwd, vim.fs.root(path, ".git") or cwd } do
    candidate = vim.fs.normalize(candidate)
    if contains(candidate, path) and (not root or #candidate > #root) then root = candidate end
  end
  return root or vim.fs.dirname(path)
end

local function path_parts(root, path, directory)
  local relative = vim.fs.relpath(root, path)
  if not relative then root = vim.fs.dirname(path); relative = vim.fs.basename(path) end
  local parts = { { label = vim.fs.basename(root), path = root, directory = true } }
  local current = root
  if relative ~= "." then
    for name in relative:gmatch("[^/\\]+") do
      current = vim.fs.joinpath(current, name)
      parts[#parts + 1] = { label = name, path = current, directory = directory or current ~= path }
    end
  end
  return parts
end

function M.update(buf)
  if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].buftype ~= "" then cache[buf] = nil; return end
  local path = vim.api.nvim_buf_get_name(buf)
  if path == "" then cache[buf] = nil; return end
  path = vim.fs.normalize(path)
  cache[buf] = path_parts(project_root(path), path, false)
end

local function open_file(path, source)
  if not vim.api.nvim_win_is_valid(source) then
    vim.notify("The source window was closed", vim.log.levels.INFO)
    return
  end
  vim.api.nvim_set_current_win(source)
  -- :edit respects modified-buffer protection; never use :edit! or change cwd.
  vim.cmd.edit(vim.fn.fnameescape(path))
end

local label_anchor

function M.browse(directory, source, anchor, root)
  source = source or require("ui.buffers").source_win() or vim.api.nvim_get_current_win()
  directory = vim.fs.normalize(vim.fn.fnamemodify(directory, ":p"))
  root = root or project_root(directory, source)
  anchor = anchor or label_anchor(source)
  local entry = {
    buf = vim.api.nvim_win_get_buf(source), tab = vim.api.nvim_get_current_tabpage(),
    index = anchor.index, ellipsis = anchor.ellipsis,
    parts = display_parts(vim.api.nvim_win_get_buf(source)),
  }
  local generation, menu = 0
  local function list(path, navigate)
    if menu.closed or not contains(root, path) then return end
    directory, generation = path, generation + 1
    menu.directory = directory
    if navigate then
      require("ui.statusline_hover").clear()
      -- Apply the chosen directory to this navigation session, not the source
      -- buffer or cwd. Re-anchor under its new breadcrumb before loading it.
      entry.parts = path_parts(root, path, true)
      entry.index, entry.ellipsis = #entry.parts, false
      vim.cmd.redrawstatus()
      local next_anchor = label_anchor(source, entry.index)
      next_anchor.row = menu.anchor.row
      menu.anchor = next_anchor
      entry.index, entry.ellipsis = next_anchor.index, next_anchor.ellipsis
    end
    local request = generation
    menu:update({ { label = "Loading…" } })
    vim.uv.fs_scandir(path, function(err, handle)
      local entries = {}
      if handle then
        while true do
          local name, kind = vim.uv.fs_scandir_next(handle)
          if not name then break end
          entries[#entries + 1] = { name = name, kind = kind }
        end
      end
      vim.schedule(function()
        if menu.closed or request ~= generation or not vim.api.nvim_buf_is_valid(menu.buf) then return end
        if err then menu:update({ { label = "Cannot read directory: " .. err } }); return end
        table.sort(entries, function(a, b)
          if (a.kind == "directory") ~= (b.kind == "directory") then return a.kind == "directory" end
          return a.name:lower() < b.name:lower()
        end)
        local items = {}
        for _, entry in ipairs(entries) do
          local target = vim.fs.joinpath(path, entry.name)
          items[#items + 1] = {
            label = (entry.kind == "directory" and "󰉋" or require("ui.file_icons").get(entry.name)) .. " " .. entry.name,
            action = function()
              local stat = vim.uv.fs_stat(target) -- follows directory symlinks on selection
              if stat and stat.type == "directory" then list(target, true)
              elseif stat and stat.type == "file" then menu:close(); open_file(target, source)
              else vim.notify("Path is no longer available: " .. target, vim.log.levels.WARN) end
            end,
          }
        end
        menu:update(items)
      end)
    end)
  end
  menu = require("ui.menu").open {
    source = source, anchor = anchor,
    selection = "DottedBreadcrumbSelection",
    parent = function() list(vim.fs.dirname(directory), true) end,
    on_outside_click = function(_, mouse)
      if mouse.screenrow - 1 ~= menu.anchor.row then return end
      local target = label_anchor(source, nil, mouse)
      if not target.hit then return end
      -- Resolve the applied path before closing can restore the file path.
      _G.DottedBreadcrumbClick(entry.buf * 1000 + target.index)
      return true
    end,
    on_close = function()
      if opened == entry then opened = nil; vim.cmd.redrawstatus() end
    end,
  }
  entry.menu = menu
  opened = entry
  vim.cmd.redrawstatus()
  menu.root = root
  list(directory)
  return menu
end

function M.pick()
  local source = require("ui.buffers").source_win() or vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_win_get_buf(source)
  local path = vim.api.nvim_buf_get_name(buf)
  local parts = cache[buf]
  return M.browse(path ~= "" and vim.fs.dirname(path) or vim.fn.getcwd(), source, nil, parts and parts[1].path)
end

local function visible_parts(buf, width)
  local parts = display_parts(buf)
  if not parts then return {} end
  local selected = {}
  for index, part in ipairs(parts) do
    local label = part.directory and part.label or require("ui.file_icons").get(part.label) .. " " .. part.label
    selected[#selected + 1] = { index = index, label = label }
  end
  local budget = math.max(12, math.floor(width * 0.32))
  local function size()
    local n = 0
    for _, part in ipairs(selected) do n = n + vim.fn.strdisplaywidth(part.label) + 3 end
    return n
  end
  while #selected > 2 and size() > budget do
    table.remove(selected, 2)
  end
  if #selected < #parts then table.insert(selected, 2, { index = 1, label = "…" }) end
  return selected, budget
end

function M.render(buf, width)
  if not display_parts(buf) then return nil end
  local selected, budget = visible_parts(buf, width)
  local result = {}
  for ordinal, part in ipairs(selected) do
    local label = part.label
    if #selected <= 2 and vim.fn.strdisplaywidth(label) > budget then label = vim.fn.strcharpart(label, 0, budget - 1) .. "…" end
    -- Native highlight spans provide exact screen-cell positions, including
    -- mode/icon prefixes, Unicode labels, alignment and statusline truncation.
    local active = opened and opened.buf == buf and opened.tab == vim.api.nvim_get_current_tabpage()
      and opened.index == part.index and (not not opened.ellipsis) == (part.label == "…")
    local hover = require("ui.statusline_hover").breadcrumb(buf, ordinal)
    local group = active and "DottedBreadcrumbActive" or hover and "DottedBreadcrumbHover" or "DottedBreadcrumb"
    result[#result + 1] = ("%%%d@v:lua.DottedBreadcrumbClick@%%#%s#%s%%#DottedSt_file#%%X")
      :format(buf * 1000 + part.index, group, escape(label))
  end
  return table.concat(result, " > ")
end

label_anchor = function(source, index, mouse)
  local buf = vim.api.nvim_win_get_buf(source)
  local parts = display_parts(buf)
  index = index or (parts and math.max(1, #parts - 1))
  local anchor = {
    row = mouse and mouse.screenrow > 0 and mouse.screenrow - 1 or vim.o.lines - vim.o.cmdheight - 1,
    col = vim.api.nvim_win_get_position(source)[2],
  }
  local status = vim.api.nvim_eval_statusline(vim.o.statusline, {
    winid = vim.api.nvim_get_current_win(), maxwidth = vim.o.columns, highlights = true,
  })
  local selected, number, first, wanted = visible_parts(buf, vim.o.columns), 0, nil, nil
  for i, part in ipairs(selected) do
    if part.index == index then wanted = i; break end
  end
  if not wanted then
    for i, part in ipairs(selected) do if part.label == "…" then wanted = i; break end end
  end
  local function component(number)
    local part = selected[number]
    if part then anchor.index, anchor.ellipsis = part.index, part.label == "…" end
  end
  component(wanted or 1)
  for i, span in ipairs(status.highlights) do
    if span.group == "DottedBreadcrumb" or span.group == "DottedBreadcrumbHover" or span.group == "DottedBreadcrumbActive" then
      number = number + 1
      local col = vim.fn.strdisplaywidth(status.str:sub(1, span.start))
      local ending = status.highlights[i + 1]
      local finish = ending and vim.fn.strdisplaywidth(status.str:sub(1, ending.start)) or status.width
      if mouse and mouse.screencol - 1 >= col and mouse.screencol - 1 < finish then
        anchor.col = col
        anchor.hit = true
        component(number)
        return anchor
      end
      if number == (wanted or 1) then first = col end
    end
  end
  anchor.col = first or anchor.col
  return anchor
end

function M.setup()
  if not startup_root and vim.fn.argc() == 1 and vim.fn.isdirectory(vim.fn.argv(0)) == 1 then
    startup_root = vim.uv.fs_realpath(vim.fn.argv(0)) or vim.fs.normalize(vim.fn.fnamemodify(vim.fn.argv(0), ":p"))
  end
  _G.DottedBreadcrumbClick = function(id)
    local buf, index = math.floor(id / 1000), id % 1000
    local parts = display_parts(buf)
    local part = parts and parts[index]
    if not part then return end
    local source = require("ui.buffers").source_win() or vim.api.nvim_get_current_win()
    -- Anchor to the label's left edge, not the character the mouse happened to
    -- hit. Capture before scheduling; retain it throughout async navigation.
    local mouse = vim.fn.getmousepos()
    local anchor = label_anchor(source, index, mouse)
    local root = parts[1].path
    vim.schedule(function()
      if part.directory then M.browse(part.path, source, anchor, root)
      else
        if opened and opened.menu then opened.menu:close() end
        open_file(part.path, source)
      end
    end)
  end
  local group = vim.api.nvim_create_augroup("DottedBreadcrumbs", { clear = true })
  local function highlights()
    vim.api.nvim_set_hl(0, "DottedBreadcrumb", { link = "DottedSt_file" })
    vim.api.nvim_set_hl(0, "DottedBreadcrumbActive", { link = "DottedBreadcrumbSelection" })
  end
  vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = highlights })
  highlights()
  vim.api.nvim_create_autocmd({ "BufEnter", "BufFilePost", "BufWritePost" }, { group = group, callback = function(args) M.update(args.buf) end })
  vim.api.nvim_create_autocmd("DirChanged", { group = group, callback = function()
    for _, buf in ipairs(require("ui.buffers").list()) do M.update(buf) end
  end })
  vim.api.nvim_create_autocmd("BufWipeout", { group = group, callback = function(args) cache[args.buf] = nil end })
  M.update(vim.api.nvim_get_current_buf())
end
return M
