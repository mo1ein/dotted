-- Render the keymap Markdown as readable tables, even without Treesitter parsers.
local M = {}
local namespace = vim.api.nvim_create_namespace "OwnedKeymapPreview"
local function width(text) return vim.fn.strdisplaywidth(text) end
local function plain(text)
  return vim.trim(text):gsub("`", ""):gsub(" _%((.-)%)_", " (%1)"):gsub("\31", "|")
end
local function cells(line)
  local escaped = line:sub(2, -2):gsub("\\|", "\31")
  return vim.tbl_map(plain, vim.split(escaped, "|", { plain = true }))
end
local function wrap(text, size)
  local out, line = {}, ""
  for word in text:gmatch "%S+" do
    if line ~= "" and width(line .. " " .. word) <= size then line = line .. " " .. word
    else
      if line ~= "" then out[#out + 1] = line; line = "" end
      for _, char in ipairs(vim.fn.split(word, "\\zs")) do
        if line ~= "" and width(line .. char) > size then out[#out + 1] = line; line = "" end
        line = line .. char
      end
    end
  end
  out[#out + 1] = line
  return out
end

function M.render(source, available)
  local out, marks = {}, {}
  local function add(text, group)
    out[#out + 1] = text
    if group then marks[#marks + 1] = { row = #out - 1, start = 0, finish = #text, group = group } end
  end
  local function table_rows(rows)
    local count, sizes = #rows[1], {}
    -- Very narrow terminals use stacked records instead of clipping columns.
    if available < count * 6 + 1 then
      for i = 2, #rows do
        for col = 1, count do
          for _, line in ipairs(wrap(rows[1][col] .. ": " .. (rows[i][col] or ""), available)) do add(line, col == 1 and "Special" or nil) end
        end
        add("")
      end
      return
    end
    for col = 1, count do
      sizes[col] = 1
      for _, row in ipairs(rows) do sizes[col] = math.max(sizes[col], width(row[col] or "")) end
    end
    local budget, total = available - count * 3 - 1, 0
    for _, size in ipairs(sizes) do total = total + size end
    while total > budget do
      local widest = 1
      for col = 2, count do if sizes[col] > sizes[widest] then widest = col end end
      sizes[widest], total = sizes[widest] - 1, total - 1
    end
    local function border(left, middle, right)
      local parts = {}
      for _, size in ipairs(sizes) do parts[#parts + 1] = string.rep("─", size + 2) end
      add(left .. table.concat(parts, middle) .. right, "FloatBorder")
    end
    border("╭", "┬", "╮")
    for index, row in ipairs(rows) do
      local wrapped, height = {}, 1
      for col = 1, count do wrapped[col] = wrap(row[col] or "", sizes[col]); height = math.max(height, #wrapped[col]) end
      for n = 1, height do
        local text = "│"
        for col = 1, count do
          local value = wrapped[col][n] or ""
          local start = #text + 1
          text = text .. " " .. value .. string.rep(" ", sizes[col] - width(value)) .. " │"
          local group = index == 1 and "Title" or ((count == 2 and col == 1 or count == 6 and (col == 4 or col == 5)) and "Special" or nil)
          if group then marks[#marks + 1] = { row = #out, start = start, finish = start + #value, group = group } end
        end
        add(text)
      end
      if index == 1 then border("├", "┼", "┤") end
    end
    border("╰", "┴", "╯")
  end
  local i = 1
  while i <= #source do
    local line = source[i]
    if line:match "^|" then
      local rows = {}
      while i <= #source and source[i]:match "^|" do
        local row = cells(source[i])
        if not (row[1] or ""):match "^:?-+:?$" then rows[#rows + 1] = row end
        i = i + 1
      end
      if #rows > 0 then table_rows(rows) end
    else
      local heading = line:match "^#+%s+(.+)"
      for _, part in ipairs(wrap(plain(heading or line), available)) do add(part, heading and "Title" or nil) end
      i = i + 1
    end
  end
  return out, marks
end

function M.open(source)
  local function dimensions()
    return math.max(1, math.min(vim.o.columns - 4, 120)), math.max(1, vim.o.lines - 6)
  end
  local w, h = dimensions()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].filetype, vim.bo[buf].bufhidden = "keymaps", "wipe"
  local function render()
    local lines, marks = M.render(source, w)
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
    for _, mark in ipairs(marks) do
      vim.api.nvim_buf_set_extmark(buf, namespace, mark.row, mark.start, { end_col = mark.finish, hl_group = mark.group })
    end
    vim.bo[buf].modifiable = false
  end
  render()
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor", width = w, height = math.min(h, vim.api.nvim_buf_line_count(buf)),
    row = math.max(0, math.floor((vim.o.lines - h) / 2) - 1), col = math.max(0, math.floor((vim.o.columns - w) / 2)),
    style = "minimal", border = "rounded", title = " keymaps ", title_pos = "center",
  })
  vim.wo[win].wrap, vim.wo[win].foldenable, vim.wo[win].conceallevel = false, false, 0
  for _, key in ipairs { "q", "<Esc>" } do vim.keymap.set("n", key, "<cmd>close<CR>", { buffer = buf, nowait = true }) end
  local resize = vim.api.nvim_create_autocmd("VimResized", { callback = function()
    if not vim.api.nvim_win_is_valid(win) then return end
    w, h = dimensions()
    render()
    vim.api.nvim_win_set_config(win, {
      relative = "editor", width = w, height = math.min(h, vim.api.nvim_buf_line_count(buf)),
      row = math.max(0, math.floor((vim.o.lines - h) / 2) - 1), col = math.max(0, math.floor((vim.o.columns - w) / 2)),
    })
  end })
  vim.api.nvim_create_autocmd("BufWipeout", { buffer = buf, once = true, callback = function() pcall(vim.api.nvim_del_autocmd, resize) end })
  return { buf = buf, win = win }
end

return M
