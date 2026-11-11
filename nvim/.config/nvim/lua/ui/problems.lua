-- A live diagnostic view inside the drawer's existing window. Trouble remains
-- available separately, but no second window manager owns this panel.
local M = {}
local namespace = vim.api.nvim_create_namespace "DottedProblems"
local hover_namespace = vim.api.nvim_create_namespace "DottedProblemsHover"
local names = { "Error", "Warn", "Info", "Hint" }
local icons = { "", "", "", "󰌵" }

function M.refresh(s)
  if not s.problems or not vim.api.nvim_buf_is_valid(s.problems) then return end
  vim.api.nvim_buf_clear_namespace(s.problems, hover_namespace, 0, -1)
  s.problem_hover = nil
  local diagnostics = vim.tbl_filter(function(diagnostic) return vim.api.nvim_buf_is_valid(diagnostic.bufnr) end, vim.diagnostic.get())
  table.sort(diagnostics, function(a, b)
    local left, right = vim.api.nvim_buf_get_name(a.bufnr), vim.api.nvim_buf_get_name(b.bufnr)
    if left ~= right then return left < right end
    if (a.severity or 1) ~= (b.severity or 1) then return (a.severity or 1) < (b.severity or 1) end
    if a.lnum ~= b.lnum then return a.lnum < b.lnum end
    return a.col < b.col
  end)
  local lines, items, highlights, previous = {}, {}, {}, nil
  for _, diagnostic in ipairs(diagnostics) do
    if vim.api.nvim_buf_is_valid(diagnostic.bufnr) then
      if previous ~= diagnostic.bufnr then
        local path = vim.api.nvim_buf_get_name(diagnostic.bufnr)
        lines[#lines + 1] = " " .. (path == "" and "[New]" or vim.fn.fnamemodify(path, ":~:."))
        highlights[#highlights + 1] = { #lines - 1, "Directory" }
        previous = diagnostic.bufnr
      end
      local severity = diagnostic.severity or vim.diagnostic.severity.ERROR
      lines[#lines + 1] = ("   %s %d:%d  %s"):format(icons[severity], diagnostic.lnum + 1, diagnostic.col + 1, diagnostic.message:gsub("[\r\n]+", " · "))
      items[#lines] = diagnostic
      highlights[#highlights + 1] = { #lines - 1, "Diagnostic" .. names[severity] }
    end
  end
  if #lines == 0 then lines = { " No problems reported." } end
  s.problem_items = items
  local cursor = s.win and vim.api.nvim_win_is_valid(s.win) and vim.api.nvim_win_get_buf(s.win) == s.problems and vim.api.nvim_win_get_cursor(s.win)
  vim.bo[s.problems].modifiable = true
  vim.api.nvim_buf_set_lines(s.problems, 0, -1, false, lines)
  vim.bo[s.problems].modifiable = false
  vim.api.nvim_buf_clear_namespace(s.problems, namespace, 0, -1)
  for _, entry in ipairs(highlights) do
    vim.api.nvim_buf_set_extmark(s.problems, namespace, entry[1], 0, { end_col = #lines[entry[1] + 1], hl_group = entry[2] })
  end
  if cursor then vim.api.nvim_win_set_cursor(s.win, { math.min(cursor[1], #lines), 0 }) end
end

function M.buffer(s)
  if not s.problems or not vim.api.nvim_buf_is_valid(s.problems) then
    s.problems = vim.api.nvim_create_buf(false, true)
    vim.bo[s.problems].filetype = "dotted_problems"
    vim.bo[s.problems].bufhidden = "hide"
    vim.keymap.set("n", "<CR>", function() M.jump(s) end, { buffer = s.problems, silent = true })
    vim.keymap.set("n", "q", function() require("ui.tools").hide() end, { buffer = s.problems, silent = true })
    vim.keymap.set("n", "<Esc>", function()
      local main = require("ui.buffers").source_win()
      if main then vim.api.nvim_set_current_win(main) end
    end, { buffer = s.problems, silent = true })
    vim.keymap.set("n", "<2-LeftMouse>", function()
      local mouse = vim.fn.getmousepos()
      if mouse.winid == s.win and mouse.line > 0 then
        vim.api.nvim_win_set_cursor(s.win, { mouse.line, 0 })
        M.jump(s)
      end
    end, { buffer = s.problems, silent = true })
  end
  M.refresh(s)
  return s.problems
end

function M.jump(s)
  if not s.win or not vim.api.nvim_win_is_valid(s.win) then return end
  local item = s.problem_items and s.problem_items[vim.api.nvim_win_get_cursor(s.win)[1]]
  if not item or not vim.api.nvim_buf_is_valid(item.bufnr) then return end
  if require("ui.buffers").is_source(s.source) then vim.api.nvim_set_current_win(s.source) end
  require("ui.buffers").focus(item.bufnr)
  local line = math.min(item.lnum + 1, vim.api.nvim_buf_line_count(item.bufnr))
  local text = vim.api.nvim_buf_get_lines(item.bufnr, line - 1, line, false)[1] or ""
  vim.api.nvim_win_set_cursor(0, { line, math.min(item.col, #text) })
end
function M.attach_hover(s)
  if s.detach_problem_hover then s.detach_problem_hover() end
  local function clear()
    if vim.api.nvim_buf_is_valid(s.problems) then vim.api.nvim_buf_clear_namespace(s.problems, hover_namespace, 0, -1) end
    s.problem_hover = nil
  end
  s.detach_problem_hover = require("ui.statusline_hover").register(s.win, function(mouse)
    if not s.problem_items or not s.problem_items[mouse.line] then return end
    if s.problem_hover ~= mouse.line then
      clear()
      s.problem_hover = mouse.line
      local text = vim.api.nvim_buf_get_lines(s.problems, mouse.line - 1, mouse.line, false)[1] or ""
      vim.api.nvim_buf_set_extmark(s.problems, hover_namespace, mouse.line - 1, 0, {
        end_col = #text, hl_group = "DottedBreadcrumbSelection", hl_eol = true, priority = 200,
      })
      vim.api.nvim_win_set_cursor(s.win, { mouse.line, 0 })
    end
    return mouse.line
  end, clear)
end
return M
