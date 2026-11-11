-- Compare against real fzf terminal output, not similarly named Vim groups.
assert(vim.env.NVIM_TEST_ISOLATED == "1")
local colors = require "ui.breadcrumb_colors"
local old_opts, old_file, old_global = vim.env.FZF_DEFAULT_OPTS, vim.env.FZF_DEFAULT_OPTS_FILE, vim.g.fzf_colors
vim.env.FZF_DEFAULT_OPTS, vim.env.FZF_DEFAULT_OPTS_FILE, vim.g.fzf_colors = nil, nil, nil
local function rendered(spec)
  local output = ""
  local command = { "fzf", "--sync", "--no-sort", "--layout=reverse", "--highlight-line" }
  if spec then command[#command + 1] = "--color=" .. spec end
  local job = vim.fn.jobstart(command, {
    pty = true, width = 100, height = 30,
    env = { TERM = "xterm-256color", FZF_DEFAULT_OPTS = "", FZF_DEFAULT_OPTS_FILE = "", FZF_DEFAULT_COMMAND = "printf 'COLOR_PROBE_ALPHA\\nCOLOR_PROBE_BETA\\n'" },
    on_stdout = function(channel, data)
      local chunk = table.concat(data, "\n")
      output = output .. chunk
      if chunk:find("\27[6n", 1, true) then vim.fn.chansend(channel, "\27[1;1R") end
      if chunk:find("\27]11;?", 1, true) then vim.fn.chansend(channel, "\27]11;rgb:1e1e/2222/2a2a\27\\") end
    end,
  })
  assert(job > 0)
  local ready = vim.wait(6000, function() return output:find("COLOR_PROBE_ALPHA", 1, true) ~= nil end, 10)
  vim.fn.jobstop(job)
  assert(ready, "fzf did not paint its selected row")
  local at = assert(output:find("COLOR_PROBE_ALPHA", 1, true))
  local prefix = output:sub(math.max(1, at - 150), at - 1)
  local foreground, background
  for value in prefix:gmatch("38;5;(%d+)") do foreground = tonumber(value) end
  for value in prefix:gmatch("48;5;(%d+)") do background = tonumber(value) end
  assert(foreground and background, "Selected-row SGR colors not found: " .. vim.inspect(prefix))
  local function gray(n) assert(n >= 232); return (8 + (n - 232) * 10) * 0x10101 end
  return gray(foreground), gray(background)
end
for _, spec in ipairs { "dark", "light" } do
  local fg, bg = rendered(spec)
  local palette = colors.resolve { fzf_opts = { ["--color"] = spec } }
  assert(palette.fg == fg and palette.bg == bg, "Breadcrumb palette differs from fzf's actual " .. spec .. " selected-row colors")
end
vim.env.FZF_DEFAULT_OPTS, vim.env.FZF_DEFAULT_OPTS_FILE, vim.g.fzf_colors = old_opts, old_file, old_global
colors.apply()
assert(vim.v.errmsg == "", vim.v.errmsg)
print "Finder colors: real fzf dark/light current-row SGR colors match breadcrumb colors; no picker styling changed"
