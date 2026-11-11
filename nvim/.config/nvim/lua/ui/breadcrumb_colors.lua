-- Resolve the finder's actual fzf current-row palette, not an unrelated Visual
-- or CursorLine fallback. This module only writes breadcrumb/hover highlights.
local M = {}
local function ansi(value)
  local n = tonumber(value)
  if not n or n < 0 or n > 255 then return nil end
  if n >= 232 then local c = 8 + (n - 232) * 10; return c * 0x10101 end
  if n >= 16 then
    local ramp = { 0, 95, 135, 175, 215, 255 }
    n = n - 16
    return ramp[math.floor(n / 36) + 1] * 65536 + ramp[math.floor(n / 6) % 6 + 1] * 256 + ramp[n % 6 + 1]
  end
  local color = vim.g["terminal_color_" .. n]
  if type(color) == "string" then return tonumber(color:match("^#(%x+)$"), 16) end
end
function M.resolve(opts)
  opts = opts or {}
  local colors = require "ui.color"
  -- fzf's 256-color defaults, verified against its rendered current row. fzf
  -- stays dark unless --color=light is set, regardless of 'background'.
  local result = { fg = ansi(254), bg = ansi(236), bold = true }
  local function raw(field, value)
    local first = tostring(value):match("^[^:]+")
    local color = first:match("^#(%x%x%x%x%x%x)$")
    if color then result[field] = tonumber(color, 16)
    elseif tonumber(first) then
      result[field] = first == "-1" and colors.get("NormalFloat")[field] or ansi(first)
    end
    for attr in tostring(value):gmatch(":([%a]+)") do
      if attr == "regular" then result.bold, result.reverse, result.underline = false, nil, nil
      elseif attr == "bold" or attr == "reverse" or attr == "underline" then result[attr] = true end
    end
  end
  local function spec(value)
    if type(value) ~= "string" then return end
    for token in value:gmatch("[^,%s]+") do
      if token == "light" then result.fg, result.bg = ansi(237), ansi(251)
      elseif token == "dark" then result.fg, result.bg = ansi(254), ansi(236)
      else
        local key, val = token:match("^([^:]+):(.+)$")
        if key == "fg+" or key == "current-fg" then raw("fg", val)
        elseif key == "bg+" or key == "current-bg" then raw("bg", val) end
      end
    end
  end
  local function env_spec(value)
    for value in (value or ""):gmatch("%-%-color[= ]+['\"]?([^'\"%s]+)") do spec(value) end
  end
  if vim.env.FZF_DEFAULT_OPTS_FILE then
    local ok, lines = pcall(vim.fn.readfile, vim.env.FZF_DEFAULT_OPTS_FILE, "", 1024)
    if ok then env_spec(table.concat(lines, " ")) end
  end
  env_spec(vim.env.FZF_DEFAULT_OPTS)
  spec(opts.fzf_opts and opts.fzf_opts["--color"])
  local mappings = vim.tbl_extend("force", type(vim.g.fzf_colors) == "table" and vim.g.fzf_colors or {},
    type(opts.fzf_colors) == "table" and opts.fzf_colors or {})
  if opts.fzf_colors == true then
    mappings = vim.tbl_extend("keep", mappings, {
      ["fg+"] = { "fg", { "FzfLuaFzfCursorLine", "FzfLuaFzfNormal" } },
      ["bg+"] = { "bg", "FzfLuaFzfCursorLine" },
    })
  end
  for flag, field in pairs { ["fg+"] = "fg", ["bg+"] = "bg" } do
    local value = mappings[flag]
    if type(value) == "string" then raw(field, value)
    elseif type(value) == "table" then
      local groups = type(value[2]) == "table" and value[2] or { value[2] }
      for _, group in ipairs(groups) do
        local color = colors.get(group)[value[1]]
        if color then result[field] = color; break end
      end
      for i = 3, #value do raw(field, "keep:" .. tostring(value[i])) end
    end
  end
  if (opts.fzf_opts and opts.fzf_opts["--no-bold"]) or (vim.env.FZF_DEFAULT_OPTS or ""):find("%-%-no%-bold") then result.bold = false end
  return result
end
function M.apply()
  local config = package.loaded["fzf-lua.config"]
  local opts = {}
  if config then
    local global = config.globals
    opts.fzf_colors, opts.fzf_opts = global.fzf_colors, global.fzf_opts
    local files = global.files or {}
    if files.fzf_opts then opts.fzf_opts = vim.tbl_extend("force", opts.fzf_opts or {}, files.fzf_opts) end
    if files.fzf_colors ~= nil then
      opts.fzf_colors = type(files.fzf_colors) == "table" and vim.tbl_extend("force",
        type(opts.fzf_colors) == "table" and opts.fzf_colors or {}, files.fzf_colors) or files.fzf_colors
    end
  end
  local palette = M.resolve(opts)
  vim.api.nvim_set_hl(0, "DottedBreadcrumbSelection", palette)
  local number = vim.deepcopy(palette)
  number.bold = true
  vim.api.nvim_set_hl(0, "DottedHoverNumber", number)
end
function M.setup()
  local group = vim.api.nvim_create_augroup("DottedBreadcrumbColors", { clear = true })
  vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = M.apply })
  vim.api.nvim_create_autocmd("User", { group = group, pattern = "LazyLoad", callback = function(args)
    if args.data == "fzf-lua" then M.apply() end
  end })
  M.apply()
end
return M
