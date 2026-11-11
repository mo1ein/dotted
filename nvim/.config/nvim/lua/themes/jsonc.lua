-- Decode data-only JSONC, preserving quoted URLs/escapes while removing comments.
local M = {}

function M.decode(raw)
  local out, i, quoted, escaped = {}, 1, false, false
  while i <= #raw do
    local c, next_c = raw:sub(i, i), raw:sub(i + 1, i + 1)
    if quoted then
      out[#out + 1] = c
      if escaped then escaped = false elseif c == "\\" then escaped = true elseif c == '"' then quoted = false end
    elseif c == '"' then quoted = true; out[#out + 1] = c
    elseif c == "/" and next_c == "/" then
      i = raw:find("\n", i + 2, true) or (#raw + 1)
      out[#out + 1] = "\n"
    elseif c == "/" and next_c == "*" then
      local finish = assert(raw:find("*/", i + 2, true), "Unterminated JSONC comment")
      i = finish + 1
      out[#out + 1] = " "
    elseif c == "," then
      -- Trailing-comma removal happens after comments have been stripped.
      out[#out + 1] = c
    else out[#out + 1] = c end
    i = i + 1
  end
  raw, out, i, quoted, escaped = table.concat(out), {}, 1, false, false
  while i <= #raw do
    local c = raw:sub(i, i)
    if quoted then
      out[#out + 1] = c
      if escaped then escaped = false elseif c == "\\" then escaped = true elseif c == '"' then quoted = false end
    elseif c == '"' then quoted = true; out[#out + 1] = c
    elseif c == "," then
      local following = raw:sub(i + 1):match "^%s*(.)"
      if following ~= "}" and following ~= "]" then out[#out + 1] = c end
    else out[#out + 1] = c end
    i = i + 1
  end
  return vim.json.decode(table.concat(out))
end

return M
