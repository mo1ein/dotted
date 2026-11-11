-- Explorer-only controls; default NvimTree mappings remain available via g?.
local M = { sort = "name", follow = true }
local controls = require "ui.controls"
local function api() return require "nvim-tree.api" end
function M.sorter(nodes)
  table.sort(nodes, function(a, b)
    if (a.type == "directory") ~= (b.type == "directory") then return a.type == "directory" end
    local left, right = a.name:lower(), b.name:lower()
    if M.sort == "extension" then
      local x, y = a.name:match("%.([^.]*)$") or "", b.name:match("%.([^.]*)$") or ""
      if x ~= y then return x < y end
    end
    return left < right
  end)
end
function M.create(folder, anchor)
  local node = api().tree.get_node_under_cursor()
  local parent = node and (node.type == "directory" and node.absolute_path or vim.fs.dirname(node.absolute_path)) or vim.fn.getcwd()
  return controls.input(folder and "New folder" or "New file", parent .. "/", function(path)
    if vim.uv.fs_stat(path) then vim.notify("Already exists: " .. path, vim.log.levels.WARN); return end
    local ok, err = pcall(function()
      if folder then assert(vim.fn.mkdir(path, "p") == 1, "Cannot create folder")
      else
        if not vim.uv.fs_stat(vim.fs.dirname(path)) then vim.fn.mkdir(vim.fs.dirname(path), "p") end
        local fd = assert(vim.uv.fs_open(path, "wx", 420))
        vim.uv.fs_close(fd)
      end
    end)
    if not ok then vim.notify(tostring(err), vim.log.levels.ERROR) end
    api().tree.reload()
  end, anchor)
end
function M.folder() return M.create(true) end
function M.toggle()
  require("lazy").load { plugins = { "nvim-tree.lua" } }
  local win = api().tree.winid()
  if win and vim.api.nvim_win_is_valid(win) then require("ui.tree_search").close(); api().tree.close() else
    api().tree.open()
    win = api().tree.winid()
    if win and M.side then
      vim.w[win].dotted_explorer_side = M.side
      vim.api.nvim_win_call(win, function() vim.cmd("wincmd " .. M.side) end)
      if M.side == "H" or M.side == "L" then vim.api.nvim_win_set_width(win, 30)
      else vim.api.nvim_win_set_height(win, 12) end
    end
  end
end
function M.move(anchor)
  anchor = anchor or controls.anchor("explorer", 7, api().tree.winid())
  controls.select("Move explorer", { "Left top", "Right top", "Top", "Bottom" }, function(choice)
    if not choice then return end
    local win = api().tree.winid()
    if not win then return end
    local side = ({ ["Left top"] = "H", ["Right top"] = "L", Top = "K", Bottom = "J" })[choice]
    M.side = side
    vim.w[win].dotted_explorer_side = side
    vim.api.nvim_win_call(win, function() vim.cmd("wincmd " .. side) end)
    if choice == "Left top" or choice == "Right top" then vim.api.nvim_win_set_width(win, 30)
    else vim.api.nvim_win_set_height(win, 12) end
  end, anchor)
end
function M.action(id, anchor)
  local tree = api()
  anchor = anchor or controls.anchor("explorer", id, tree.tree.winid())
  if id ~= 8 then require("ui.tree_search").close() end
  if id == 1 then M.create(false, anchor)
  elseif id == 2 then M.create(true, anchor)
  elseif id == 3 then tree.tree.collapse_all()
  elseif id == 4 then tree.node.expand(tree.tree.get_node_under_cursor())
  elseif id == 5 then
    controls.select("Sort explorer", { "name", "extension" }, function(value)
      if value then M.sort = value; tree.tree.reload() end
    end, anchor)
  elseif id == 6 then
    M.follow = not M.follow
    vim.notify("Explorer follows current file: " .. tostring(M.follow))
    local source = require("ui.buffers").source_win()
    if M.follow and source then tree.tree.find_file { buf = vim.api.nvim_win_get_buf(source), open = false, focus = false } end
  elseif id == 7 then M.move(anchor)
  elseif id == 8 then require("ui.tree_search").toggle()
  end
end
function M.header()
  local result = { "%#WinBar#" }
  for id, label in ipairs { "󰐕", "󰉗", "󰘕", "󰘖", "󰒺", "󰈈", "󰆾", "" } do
    result[#result + 1] = controls.button("explorer", id, label, "DottedExplorerClick", (id == 6 and M.follow) or (id == 8 and require("ui.tree_search").is_open()))
  end
  return table.concat(result)
end
function M.attach(buf)
  require("ui.explorer_selection").setup()
  api().map.on_attach.default(buf)
  local function map(key, id, desc)
    vim.keymap.set("n", key, function() M.action(id) end, { buffer = buf, desc = desc, nowait = true })
  end
  vim.keymap.set("n", "<C-e>", M.toggle, { buffer = buf, desc = "Toggle explorer", nowait = true })
  map("f", 8, "Search explorer files and folders")
  map("/", 8, "Filter explorer files and folders")
  map("<C-f>", 8, "Filter explorer files and folders")
  map("F", 2, "Create folder")
  vim.keymap.set("n", "g/", function() require("ui.tree_search").close() end, { buffer = buf, desc = "Clear explorer filter", nowait = true })
  map("gS", 5, "Sort explorer")
  map("gF", 6, "Toggle follow current file")
  map("gM", 7, "Move explorer")
  map("gE", 4, "Expand selected directory")
  _G.DottedExplorerClick = function(id)
    local anchor = controls.anchor("explorer", id, api().tree.winid())
    vim.schedule(function()
      local win = api().tree.winid()
      if win then if id ~= 8 then vim.api.nvim_set_current_win(win) end; M.action(id, anchor) end
    end)
  end
  controls.attach_winbar(buf, function() return api().tree.winid() end, "explorer", function(id) _G.DottedExplorerClick(id) end)
  local function header()
    local win = api().tree.winid()
    if win then vim.wo[win].winbar = "%!v:lua.require('ui.explorer').header()" end
  end
  header()
  local group = vim.api.nvim_create_augroup("DottedExplorer" .. buf, { clear = true })
  vim.api.nvim_create_autocmd("BufWinEnter", { group = group, buffer = buf, callback = header })
  vim.api.nvim_create_autocmd("BufWipeout", { group = group, buffer = buf, once = true,
    callback = function() pcall(vim.api.nvim_del_augroup_by_id, group) end })
end
return M
