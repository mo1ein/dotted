-- In-buffer replacement engine: literal by default, opt-in Vim regex/case/word.
local M = {}

function M.pattern(search, opts)
  opts = opts or {}
  local pattern = (opts.case_sensitive and "\\C" or "\\c") .. (opts.regex and "\\v" or "\\V")
    .. (opts.regex and search or search:gsub("\\", "\\\\"))
  if opts.word then pattern = "\\m\\<" .. pattern .. "\\m\\>" end
  local ok, err = pcall(vim.regex, pattern)
  if not ok then return nil, tostring(err) end
  return pattern
end

function M.scan(buf, search, opts)
  if search == "" then return {} end
  local pattern, err = M.pattern(search, opts)
  if not pattern then return nil, err end
  local matches = {}
  for row, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    local offset = 0
    while offset <= #line do
      local match = vim.fn.matchstrpos(line, pattern, offset)
      if match[2] < 0 then break end
      matches[#matches + 1] = { row = row - 1, start = match[2], finish = match[3] }
      offset = math.max(match[3], match[2] + 1)
    end
  end
  return matches
end

function M.preview(line, search, replacement, opts)
  if search == "" then return line end
  local pattern, err = M.pattern(search, opts)
  if not pattern then return nil, err end
  if opts and opts.regex and replacement:sub(1, 2) == "\\=" then return nil, "Expression replacements are not supported" end
  local value = opts and opts.regex and replacement or vim.fn.escape(replacement, "\\&~")
  local ok, result = pcall(vim.fn.substitute, line, pattern, value, "g")
  return ok and result or nil, not ok and result or nil
end

function M.apply(buf, search, replacement, opts, only)
  if not vim.bo[buf].modifiable or vim.bo[buf].readonly then return nil, "Buffer is read-only" end
  local matches, err = M.scan(buf, search, opts)
  if not matches then return nil, err end
  if #matches == 0 then return 0 end
  local pattern = assert(M.pattern(search, opts))
  local value = opts and opts.regex and replacement or vim.fn.escape(replacement, "\\&~")
  -- Expressions in replacement strings execute code; this UI supports text/backrefs only.
  if opts and opts.regex and replacement:sub(1, 2) == "\\=" then return nil, "Expression replacements are not supported" end
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  if only then
    local match = matches[only]
    if not match then return 0 end
    lines[match.row + 1] = vim.fn.substitute(lines[match.row + 1], "\\m\\%" .. (match.start + 1) .. "c" .. pattern, value, "")
  else
    for i, line in ipairs(lines) do lines[i] = vim.fn.substitute(line, pattern, value, "g") end
  end
  -- The source buffer is not current while its widget has focus. Explicitly
  -- finish its previous undo block so every Apply is independently undoable.
  vim.api.nvim_buf_call(buf, function() vim.cmd "let &undolevels = &undolevels" end)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  return only and 1 or #matches
end

return M
