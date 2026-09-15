-- JSON-driven keybindings, Zed style.
--
-- Keys live in keymaps/<preset>.json; what they do lives in keymaps/actions.lua.
-- A preset may `extends` another one and only list its differences, and any
-- binding may carry per-OS variants:
--
--   "editor.save": "<C-s>"                          same key everywhere
--   "editor.save": ["<C-s>", "<D-s>"]               several keys, same action
--   "editor.save": { "linux": "<C-s>",              per-OS
--                    "macos": ["<C-s>", "<D-s>"] }
--   "editor.save": false                            disabled in this preset
--
-- Pick the preset with `vim.g.keymap_preset` (see init.lua) or the
-- NVIM_KEYMAP_PRESET environment variable, which wins so a single machine can
-- deviate without touching the repo.

local actions = require "keymaps.actions"
local platform = require "util.platform"

local M = {}

local PRESET_DIR = vim.fn.stdpath "config" .. "/keymaps"
local DEFAULT_PRESET = "default"

-- which-key group labels, emitted only for prefixes the active preset uses
local GROUPS = {
  ["<leader>c"] = "code",
  ["<leader>d"] = "debug / diagnostics",
  ["<leader>f"] = "find / format",
  ["<leader>g"] = "git / go",
  ["<leader>m"] = "markdown",
  ["<leader>s"] = "search",
  ["<leader>t"] = "terminal / toggle",
  ["<leader>w"] = "workspace / which-key",
}

-- Buffer-local scopes that attach on a filetype rather than on a plugin event.
-- ("lsp" and "git" attach from LspAttach / gitsigns' on_attach instead.)
local FILETYPE_SCOPES = { markdown = "markdown" }

-- Global maps applied by the last setup(), so a preset switch can undo them.
local applied = {}
local cache = nil

-- ── preset loading ──────────────────────────────────────────────────────────

--- Drop whole-line // comments so the JSON can be annotated like Zed's keymap.
local function strip_comments(raw)
  local out = {}
  for line in (raw .. "\n"):gmatch "([^\n]*)\n" do
    if not line:match "^%s*//" then
      out[#out + 1] = line
    end
  end
  return table.concat(out, "\n")
end

function M.available()
  local names = {}
  for _, path in ipairs(vim.fn.glob(PRESET_DIR .. "/*.json", false, true)) do
    names[#names + 1] = vim.fn.fnamemodify(path, ":t:r")
  end
  table.sort(names)
  return names
end

function M.preset_name()
  return vim.env.NVIM_KEYMAP_PRESET or vim.g.keymap_preset or DEFAULT_PRESET
end

--- Read a preset and merge it over everything it extends.
--- @return { name: string, description: string?, bindings: table }
local function read_preset(name, seen)
  seen = seen or {}
  if seen[name] then
    error("keymaps: circular 'extends' involving preset '" .. name .. "'")
  end
  seen[name] = true

  local path = PRESET_DIR .. "/" .. name .. ".json"
  if vim.fn.filereadable(path) == 0 then
    error(("keymaps: preset '%s' not found (%s)"):format(name, path))
  end

  local raw = strip_comments(table.concat(vim.fn.readfile(path), "\n"))
  local ok, data = pcall(vim.json.decode, raw, { luanil = { object = true, array = true } })
  if not ok then
    error(("keymaps: %s is not valid JSON — %s"):format(path, data))
  end

  local bindings = data.extends and read_preset(data.extends, seen).bindings or {}
  for action, value in pairs(data.bindings or {}) do
    bindings[action] = value
  end

  return {
    name = data.name or name,
    description = data.description,
    extends = data.extends,
    bindings = bindings,
  }
end

-- ── key resolution ──────────────────────────────────────────────────────────

--- Turn a binding value into the key list for this OS.
--- @return string[] keys, string|table|nil mode_override
local function normalize(value, os_name)
  if value == nil or value == false or value == vim.NIL then
    return {}, nil
  end
  if type(value) == "string" then
    return { value }, nil
  end
  if vim.islist(value) then
    return vim.deepcopy(value), nil
  end

  -- object form: OS-specific key wins, then "default"
  local chosen = value[os_name]
  if chosen == nil then
    chosen = value.default
  end
  return (normalize(chosen, os_name)), value.mode
end

--- Resolve a preset into a flat, sorted list of bindings.
--- @param os_name string? defaults to the running OS
--- @param preset_name string? defaults to the active preset
function M.resolve(os_name, preset_name)
  os_name = os_name or platform.name()
  local preset = read_preset(preset_name or M.preset_name())
  local list = {}

  for action, value in pairs(preset.bindings) do
    local spec = actions[action]
    if not spec then
      vim.notify(
        ("keymaps: preset '%s' binds unknown action '%s'"):format(preset.name, action),
        vim.log.levels.WARN
      )
    else
      local keys, mode_override = normalize(value, os_name)
      if #keys > 0 then
        list[#list + 1] = {
          action = action,
          group = action:match "^([^.]+)" or "other",
          keys = keys,
          mode = mode_override or spec.mode or "n",
          desc = spec.desc,
          rhs = spec.rhs,
          opts = spec.opts,
          scope = spec.scope or "global",
        }
      end
    end
  end

  table.sort(list, function(a, b)
    return a.action < b.action
  end)
  return { preset = preset, os = os_name, bindings = list }
end

--- Cached resolve() for the running OS.
function M.current()
  if not cache then
    cache = M.resolve()
  end
  return cache
end

-- ── applying ────────────────────────────────────────────────────────────────

local function set(entry, bufnr)
  local opts = vim.tbl_extend("force", { desc = entry.desc }, entry.opts or {})
  if bufnr then
    opts.buffer = bufnr
  end
  for _, key in ipairs(entry.keys) do
    local ok, err = pcall(vim.keymap.set, entry.mode, key, entry.rhs, opts)
    if not ok then
      vim.notify(("keymaps: could not map %s (%s) — %s"):format(key, entry.action, err), vim.log.levels.WARN)
    elseif not bufnr then
      applied[#applied + 1] = { mode = entry.mode, key = key }
    end
  end
end

local function unapply()
  for _, m in ipairs(applied) do
    pcall(vim.keymap.del, m.mode, m.key)
  end
  applied = {}
end

--- Apply the buffer-local bindings of one scope ("lsp", "git", ...).
--- Called from the LspAttach hook and gitsigns' on_attach.
function M.apply_buffer(bufnr, scope)
  for _, entry in ipairs(M.current().bindings) do
    if entry.scope == scope then
      set(entry, bufnr)
    end
  end
end

--- which-key group spec for the prefixes the active preset actually uses.
function M.which_key_groups()
  local counts = {}
  for _, entry in ipairs(M.current().bindings) do
    for _, key in ipairs(entry.keys) do
      local prefix = key:match "^(<leader>.)"
      if prefix then
        counts[prefix] = (counts[prefix] or 0) + 1
      end
    end
  end

  local spec = {}
  for prefix, label in pairs(GROUPS) do
    if (counts[prefix] or 0) > 1 then
      spec[#spec + 1] = { prefix, group = label }
    end
  end
  return spec
end

-- ── entry point ─────────────────────────────────────────────────────────────

function M.setup()
  cache = nil
  unapply()

  local ok, err = pcall(function()
    for _, entry in ipairs(M.current().bindings) do
      if entry.scope == "global" then
        set(entry)
      end
    end
  end)

  if not ok then
    vim.notify("keymaps: " .. tostring(err), vim.log.levels.ERROR)
    return
  end

  -- Attach filetype-scoped bindings. Cleared and re-created on every setup()
  -- so switching presets does not stack duplicate autocmds.
  local group = vim.api.nvim_create_augroup("KeymapsFiletype", { clear = true })
  for ft, scope in pairs(FILETYPE_SCOPES) do
    vim.api.nvim_create_autocmd("FileType", {
      group = group,
      pattern = ft,
      callback = function(args)
        M.apply_buffer(args.buf, scope)
      end,
    })
  end

  -- Catch up on buffers whose FileType already fired before this autocmd
  -- existed (e.g. a file opened straight from the command line, since this
  -- setup() itself runs on a deferred vim.schedule).
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      local scope = FILETYPE_SCOPES[vim.bo[buf].filetype]
      if scope then
        M.apply_buffer(buf, scope)
      end
    end
  end

  require("keymaps.table").register_commands()

  vim.api.nvim_create_user_command("KeymapPreset", function(args)
    if args.args == "" then
      vim.notify(
        ("keymap preset: %s\navailable: %s"):format(M.preset_name(), table.concat(M.available(), ", ")),
        vim.log.levels.INFO
      )
      return
    end
    if not vim.tbl_contains(M.available(), args.args) then
      vim.notify("keymaps: no such preset '" .. args.args .. "'", vim.log.levels.ERROR)
      return
    end
    vim.g.keymap_preset = args.args
    vim.env.NVIM_KEYMAP_PRESET = nil
    M.setup()
    vim.notify(
      ("keymap preset → %s (buffer-local LSP/git maps update on next attach)"):format(args.args),
      vim.log.levels.INFO
    )
  end, {
    nargs = "?",
    desc = "Show or switch the active keybinding preset",
    complete = function()
      return M.available()
    end,
  })
end

return M
