-- Theme activation, live previews, and confirmed config-backed selection.
local M = {}
local names, startup, current, background_override

function M.current()
  return current or vim.g.colors_name
end

function M.names()
  if not names then
    local set = {}
    for _, name in ipairs(vim.fn.getcompletion("", "color")) do set[name] = true end
    for _, entry in ipairs(require("themes.catalog").entries()) do
      for _, name in ipairs(entry.schemes) do set[name] = true end
    end
    names = vim.fn.sort(vim.tbl_keys(set))
  end
  return vim.deepcopy(names)
end

function M.startup()
  if startup then return startup end
  startup = require("config.theme").colorscheme
  local selection = require "themes.selection"
  local chosen, err = selection.read()
  if err then vim.notify(err, vim.log.levels.WARN) end
  if chosen and vim.tbl_contains(M.names(), chosen) then startup = chosen; return startup end
  local statefile = selection.legacy_path()
  if vim.fn.filereadable(statefile) == 1 then
    local saved = vim.fn.readfile(statefile, "", 1)[1]
    if saved and vim.tbl_contains(M.names(), saved) then startup = saved end
  end
  return startup
end

function M.source(scheme)
  local entry = assert(require("themes.catalog").find(scheme), "Theme not in catalog: " .. scheme)
  if entry.bundled then
    require("themes.bundled").load(scheme, entry.opts, background_override)
    return
  end
  local plugin = require("lazy.core.config").plugins[entry.name]
  if not plugin or not vim.uv.fs_stat(plugin.dir .. "/colors") then
    error("Theme is not installed: " .. scheme .. ". Run :Lazy install first.")
  end
  require("lazy").load { plugins = { entry.name } }
  -- Set the next background without reloading the previous scheme.
  vim.g.colors_name = nil
  local configured = require "config.theme"
  local background = scheme == configured.colorscheme and configured.background or nil
  vim.o.background = background_override or background or (vim.tbl_contains(entry.light or {}, scheme) and "light" or entry.background or "dark")
  for _, ext in ipairs { "lua", "vim" } do
    local path = plugin.dir .. "/colors/" .. scheme .. "." .. ext
    if vim.fn.filereadable(path) == 1 then
      -- Source the real entry directly, never recursively call our forwarding file.
      if ext == "lua" then dofile(path) else vim.cmd.source(vim.fn.fnameescape(path)) end
      return
    end
  end
  error("Provider has no colorscheme named " .. scheme)
end

function M.apply(scheme, remember, background)
  scheme = scheme or M.startup()
  local previous = M.current()
  local saved_override = background_override
  background_override = background
  local ok, err = pcall(function()
    if background then vim.g.colors_name = nil; vim.o.background = background end
    local entry = require("themes.catalog").find(scheme)
    if entry and not entry.plugin and not entry.bundled and entry.module then
      local opts = type(entry.opts) == "function" and entry.opts() or entry.opts
      require(entry.module).setup(opts or {})
    end
    vim.cmd.colorscheme(scheme)
  end)
  background_override = saved_override
  if not ok then
    if previous then pcall(vim.cmd.colorscheme, previous) end
    vim.notify(tostring(err), vim.log.levels.ERROR)
    return false
  end
  if remember then
    local saved, err = require("themes.selection").save(scheme)
    if not saved then
      if previous and previous ~= scheme then pcall(M.apply, previous, false) end
      vim.notify("Theme was not saved: " .. tostring(err), vim.log.levels.ERROR)
      return false
    end
    startup = scheme
    vim.notify("Theme saved in config: " .. scheme)
  end
  return true
end

function M.pick(remember)
  if remember == nil then remember = true end
  local picker = require "config.theme_picker"
  local items = M.names()
  local active = M.current()
  for i, name in ipairs(items) do
    if name == active then table.remove(items, i); table.insert(items, 1, name); break end
  end
  local session = require("themes.preview").new(M, remember, picker.preview_delay)
  function session.select(name)
    session.choose(name, function(selected, callback)
      return require("ui.confirm").open('Are you sure? Use "' .. selected .. '"?', callback)
    end)
  end
  -- Reuse the existing searchable picker only on demand; no extra picker plugin.
  if vim.fn.executable "fzf" == 1 then
    local ok, fzf = pcall(require, "fzf-lua")
    if ok then
      local opts = {
        prompt = "Themes> ",
        no_resume = true,
        fzf_opts = {
          ["--no-multi"] = true, ["--preview-window"] = "nohidden:right:0",
          ["--header"] = "Move: preview · Enter: confirm and save · Esc: restore",
        },
        actions = {
          ["enter"] = function(selected) session.select(selected and selected[1]) end,
          ["esc"] = function() session.finish() end,
          ["ctrl-c"] = function() session.finish() end,
        },
        winopts = { height = picker.height, on_close = function()
          session.stop()
          -- fzf closes its window before running the selected action. Defer the
          -- cancellation fallback so Enter can commit without an intermediate reset.
          vim.schedule(function() session.cancel_if_idle() end)
        end },
      }
      opts.preview = require("fzf-lua.shell").stringify_data(function(selected)
        session.hover(selected and selected[1])
        return ""
      end, opts, "{}")
      local opened, err = pcall(fzf.fzf_exec, items, opts)
      if not opened then session.finish(); vim.notify(tostring(err), vim.log.levels.ERROR) end
      return
    end
  end
  return require("ui.theme_picker").open(items, session)
end

function M.setup()
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("ThemeSelection", { clear = true }),
    -- Some providers use one colors_name for several variants. Remember the
    -- requested name without modifying the provider's own globals.
    callback = function(args) current = args.match end,
  })
  vim.api.nvim_create_user_command("Theme", function(args)
    if args.args == "" then M.pick() else M.apply(args.args, args.bang) end
  end, {
    nargs = "?", bang = true, desc = "Preview, confirm and save a theme; ! saves a named theme directly",
    complete = function(prefix)
      return vim.tbl_filter(function(name) return name:sub(1, #prefix) == prefix end, M.names())
    end,
  })
  vim.api.nvim_create_user_command("ThemeReset", function()
    local ok, err = require("themes.selection").reset()
    if not ok then vim.notify(tostring(err), vim.log.levels.ERROR); return end
    startup = require("config.theme").colorscheme
    M.apply(startup)
  end, { desc = "Forget the saved theme and use config/theme.lua" })
  local entry = require("themes.catalog").find(M.startup())
  if entry and entry.bundled then require("themes.catalog").index() end
  if not entry or not entry.plugin then
    if not M.apply() then vim.cmd.colorscheme "habamax" end
  end
end

return M
