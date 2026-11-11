-- Owned, grouped terminal cheatsheet built from the same presets as :Keymaps.
local M = {}
local popup
local namespace = vim.api.nvim_create_namespace "OwnedCheatsheet"

local function width(text) return vim.fn.strdisplaywidth(text) end
local function pad(text, size) return text .. string.rep(" ", math.max(0, size - width(text))) end

local function wrap(text, size)
  local lines, line = {}, ""
  for word in text:gmatch "%S+" do
    if line ~= "" and width(line .. " " .. word) <= size then line = line .. " " .. word
    else
      if line ~= "" then lines[#lines + 1] = line; line = "" end
      for _, char in ipairs(vim.fn.split(word, "\\zs")) do
        if width(line .. char) > size and line ~= "" then lines[#lines + 1] = line; line = "" end
        line = line .. char
      end
    end
  end
  lines[#lines + 1] = line
  return lines
end

local function keys(entry)
  local out = {}
  for _, key in ipairs(entry.keys) do
    out[#out + 1] = key:gsub("<[Ll][Ee][Aa][Dd][Ee][Rr]>", "Space ")
      :gsub("<C%-([^>]+)>", "Ctrl-%1"):gsub("<D%-([^>]+)>", "Cmd-%1")
      :gsub("<[AM]%-([^>]+)>", "Alt-%1")
  end
  return table.concat(out, " · ")
end

-- Pure layout function used by the popup and tests. Highlight ranges use bytes.
function M.render(preset, available_width, os_name)
  local config = require "config.cheatsheet"
  local sections = require("keymaps.table").sections(preset, os_name)
  local count = math.max(1, math.min(config.max_columns,
    math.floor((available_width + config.column_gap) / (config.column_width + config.column_gap))))
  local cell_width = math.max(1, math.floor((available_width - config.column_gap * (count - 1)) / count))
  local columns = {}
  for i = 1, count do columns[i] = {} end
  for _, section in ipairs(sections) do
    local column = columns[1]
    for _, candidate in ipairs(columns) do if #candidate < #column then column = candidate end end
    local function add(text, group) column[#column + 1] = { text = text, group = group } end
    for _, line in ipairs(wrap(section.title, cell_width)) do add(line, "Title") end
    add(string.rep("─", cell_width), "FloatBorder")
    for _, entry in ipairs(section.rows) do
      local mode = type(entry.mode) == "table" and table.concat(entry.mode, ",") or entry.mode
      local description = entry.desc .. (mode ~= "n" and (" [" .. mode .. "]") or "")
      if entry.scope == "lsp" or entry.scope == "git" then description = description .. " (" .. entry.scope .. ")" end
      -- On tiny terminals stack keys above descriptions rather than clipping them.
      if cell_width < 24 then
        for _, line in ipairs(wrap(keys(entry), cell_width)) do add(line, "Special") end
        for _, line in ipairs(wrap(description, cell_width)) do add(line, "NormalFloat") end
      else
        local key_width = math.min(20, math.floor(cell_width * 0.43))
        local key_lines = wrap(keys(entry), key_width)
        local desc_lines = wrap(description, cell_width - key_width - 2)
        for i = 1, math.max(#key_lines, #desc_lines) do
          local key = pad(key_lines[i] or "", key_width)
          column[#column + 1] = { text = key .. "  " .. (desc_lines[i] or ""), key_end = #key }
        end
      end
    end
    add("")
    add("")
  end
  local lines = { "CHEATSHEET · " .. preset, " / search · n/N next/previous · j/k scroll · q/Esc close", "" }
  -- Wrap the banner as well so the whole view works in small terminal windows.
  local banner = {}
  for _, line in ipairs(lines) do vim.list_extend(banner, wrap(line, available_width)) end
  lines = banner
  local marks = { { row = 0, start = 0, finish = #lines[1], group = "Title" } }
  local height = 0
  for _, column in ipairs(columns) do height = math.max(height, #column) end
  for row = 1, height do
    local line = ""
    for i, column in ipairs(columns) do
      local cell = column[row] or { text = "" }
      local start = #line
      line = line .. pad(cell.text, cell_width)
      if cell.group then marks[#marks + 1] = { row = #lines, start = start, finish = start + #cell.text, group = cell.group }
      elseif cell.key_end then marks[#marks + 1] = { row = #lines, start = start, finish = start + cell.key_end, group = "Special" } end
      if i < count then line = line .. string.rep(" ", config.column_gap) end
    end
    lines[#lines + 1] = line
  end
  return lines, marks, count
end

function M.close()
  if popup and vim.api.nvim_win_is_valid(popup.win) then vim.api.nvim_win_close(popup.win, true) end
  popup = nil
end

function M.open(preset)
  M.close()
  preset = preset or require("keymaps").preset_name()
  local config = require "config.cheatsheet"
  local function dimensions()
    return math.max(1, math.min(config.max_width, math.floor(vim.o.columns * config.width), vim.o.columns - 4)),
      math.max(1, math.min(math.floor(vim.o.lines * config.height), vim.o.lines - 4))
  end
  local w, h = dimensions()
  -- Resolve before creating UI so a misspelled preset cannot leave an empty window.
  local lines, marks = M.render(preset, w)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "cheatsheet"
  local function contents(content, highlights)
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
    vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
    for _, mark in ipairs(highlights) do
      vim.api.nvim_buf_set_extmark(buf, namespace, mark.row, mark.start,
        { end_col = mark.finish, hl_group = mark.group })
    end
    vim.bo[buf].modifiable = false
  end
  contents(lines, marks)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor", style = "minimal", border = "rounded", title = " Cheatsheet ",
    width = w, height = h, row = math.max(0, math.floor((vim.o.lines - h) / 2) - 1),
    col = math.max(0, math.floor((vim.o.columns - w) / 2)),
  })
  vim.wo[win].wrap = false
  vim.wo[win].cursorline = true
  popup = { buf = buf, win = win }
  for _, key in ipairs { "q", "<Esc>" } do
    vim.keymap.set("n", key, M.close, { buffer = buf, nowait = true, silent = true })
  end
  local group = vim.api.nvim_create_augroup("OwnedCheatsheetWindow", { clear = true })
  vim.api.nvim_create_autocmd("VimResized", { group = group, callback = function()
    if not vim.api.nvim_win_is_valid(win) then return end
    w, h = dimensions()
    local content, highlights = M.render(preset, w)
    contents(content, highlights)
    vim.api.nvim_win_set_config(win, {
      relative = "editor", width = w, height = h, row = math.max(0, math.floor((vim.o.lines - h) / 2) - 1),
      col = math.max(0, math.floor((vim.o.columns - w) / 2)),
    })
  end })
  vim.api.nvim_create_autocmd("BufWipeout", { group = group, buffer = buf, once = true, callback = function()
    if popup and popup.buf == buf then popup = nil end
    vim.api.nvim_del_augroup_by_id(group)
  end })
  return popup
end

function M.toggle(preset)
  if popup and vim.api.nvim_win_is_valid(popup.win) then M.close() else return M.open(preset) end
end

return M
