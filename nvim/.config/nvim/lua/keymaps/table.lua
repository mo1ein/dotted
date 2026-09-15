-- Renders the active keybindings as a Markdown table.
--
--   :Keymaps            preview the active preset in a floating window
--   :Keymaps <preset>   preview another preset
--   :KeymapsWrite [path]  write every preset to docs/KEYMAPS.md in the repo
--
-- Both columns are always produced, so the table answers "what do I press on
-- the other machine?" without having to boot that machine.

local platform = require "util.platform"

local M = {}

local MODIFIER_NAMES = { C = "Ctrl", D = "Cmd", A = "Alt", M = "Alt", S = "Shift" }

-- How a buffer-local scope is annotated in the Description column
local SCOPE_NOTES = {
  lsp = "LSP buffers",
  git = "git buffers",
  markdown = "markdown buffers",
}

local GROUP_TITLES = {
  editor = "Editor",
  insert = "Insert mode",
  window = "Windows",
  buffer = "Buffers",
  ui = "UI",
  find = "Find & replace",
  markdown = "Markdown",
  terminal = "Terminal",
  git = "Git",
  lsp = "LSP",
  debug = "Debug",
  go = "Go",
}

local GROUP_ORDER = {
  "editor", "insert", "window", "buffer", "ui",
  "find", "markdown", "terminal", "git", "lsp", "debug", "go",
}

-- ── formatting helpers ──────────────────────────────────────────────────────

--- Human-readable modifier list for a set of keys, e.g. "Ctrl, Cmd".
local function modifiers_of(keys)
  local seen, out = {}, {}
  local function add(name)
    if not seen[name] then
      seen[name] = true
      out[#out + 1] = name
    end
  end

  for _, key in ipairs(keys) do
    if key:lower():find("<leader>", 1, true) then
      add "Leader"
    end
    for chord in key:gmatch "<([^>]+)>" do
      if chord:lower() ~= "leader" then
        for letter in chord:gmatch "(%a)%-" do
          local name = MODIFIER_NAMES[letter:upper()]
          if name then
            add(name)
          end
        end
      end
    end
  end

  return #out > 0 and table.concat(out, ", ") or "—"
end

local function fmt_keys(keys)
  if not keys or #keys == 0 then
    return "—"
  end
  local parts = {}
  for _, key in ipairs(keys) do
    -- escape the cell separator so a literal bar cannot break the table
    parts[#parts + 1] = "`" .. key:gsub("|", "\\|") .. "`"
  end
  return table.concat(parts, " ")
end

local function fmt_mode(mode)
  local list = type(mode) == "table" and mode or { mode }
  return "`" .. table.concat(list, "` `") .. "`"
end

-- ── row building ────────────────────────────────────────────────────────────

--- Merge the Linux and macOS resolutions of one preset into comparable rows.
local function rows_for(preset_name)
  local keymaps = require "keymaps"
  local merged, order = {}, {}

  for _, os_name in ipairs { "linux", "macos" } do
    local resolved = keymaps.resolve(os_name, preset_name)
    for _, entry in ipairs(resolved.bindings) do
      local row = merged[entry.action]
      if not row then
        row = {
          action = entry.action,
          group = entry.group,
          desc = entry.desc,
          mode = entry.mode,
          scope = entry.scope,
        }
        merged[entry.action] = row
        order[#order + 1] = entry.action
      end
      row[os_name] = entry.keys
    end
  end

  table.sort(order)
  local rows = {}
  for _, action in ipairs(order) do
    rows[#rows + 1] = merged[action]
  end
  return rows
end

--- Markdown for a single preset.
local function render_preset(preset_name, opts)
  opts = opts or {}
  local keymaps = require "keymaps"
  local resolved = keymaps.resolve(platform.name(), preset_name)
  local rows = rows_for(preset_name)

  local out = {}
  local function add(line)
    out[#out + 1] = line or ""
  end

  local heading = opts.heading or "#"
  add(("%s Preset `%s`"):format(heading, preset_name))
  add()
  if resolved.preset.description then
    add(resolved.preset.description)
    add()
  end
  if resolved.preset.extends then
    add(("Extends `%s` — only the differences are listed in its JSON file."):format(resolved.preset.extends))
    add()
  end

  -- bucket rows by group, known groups first
  local buckets = {}
  for _, row in ipairs(rows) do
    buckets[row.group] = buckets[row.group] or {}
    table.insert(buckets[row.group], row)
  end

  local groups = {}
  local emitted = {}
  for _, name in ipairs(GROUP_ORDER) do
    if buckets[name] then
      groups[#groups + 1] = name
      emitted[name] = true
    end
  end
  for name in pairs(buckets) do
    if not emitted[name] then
      groups[#groups + 1] = name
    end
  end

  for _, group in ipairs(groups) do
    add(("%s# %s"):format(heading, GROUP_TITLES[group] or group))
    add()
    add "| Action | Description | Mode | Linux | macOS | Modifier |"
    add "| --- | --- | --- | --- | --- | --- |"
    for _, row in ipairs(buckets[group]) do
      local keys = {}
      vim.list_extend(keys, row.linux or {})
      vim.list_extend(keys, row.macos or {})
      local desc = row.desc
      local note = SCOPE_NOTES[row.scope]
      if note then
        desc = ("%s _(%s)_"):format(desc, note)
      end
      add(("| `%s` | %s | %s | %s | %s | %s |"):format(
        row.action,
        desc,
        fmt_mode(row.mode),
        fmt_keys(row.linux),
        fmt_keys(row.macos),
        modifiers_of(keys)
      ))
    end
    add()
  end

  return out
end

--- Full document covering every preset.
function M.render_all()
  local keymaps = require "keymaps"
  local out = {
    "# Keymaps",
    "",
    "Generated by `:KeymapsWrite` — do not edit by hand.",
    "",
    ("Active preset: `%s` · this machine: `%s`"):format(keymaps.preset_name(), platform.name()),
    "",
    "Switch presets with `:KeymapPreset <name>`, or permanently via `vim.g.keymap_preset`",
    "in `nvim/.config/nvim/init.lua`. `NVIM_KEYMAP_PRESET` overrides both for one machine.",
    "",
    "`<D-…>` is Cmd. Terminal Neovim cannot receive Cmd, so those entries only fire in a",
    "GUI client (Neovide, VimR); the Ctrl variant on the same row works everywhere.",
    "",
  }

  for _, name in ipairs(keymaps.available()) do
    local ok, lines = pcall(render_preset, name, { heading = "##" })
    if ok then
      vim.list_extend(out, lines)
    else
      vim.list_extend(out, { ("## Preset `%s`"):format(name), "", "Failed to render: " .. tostring(lines), "" })
    end
  end

  return out
end

-- ── output ──────────────────────────────────────────────────────────────────

local function show_float(lines)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"

  local width = math.min(vim.o.columns - 4, 120)
  local height = math.min(vim.o.lines - 6, #lines + 2)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2) - 1,
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " keymaps ",
    title_pos = "center",
  })
  vim.wo[win].wrap = false
  vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = buf, nowait = true })
  vim.keymap.set("n", "<Esc>", "<cmd>close<CR>", { buffer = buf, nowait = true })
end

--- docs/KEYMAPS.md inside the dotfiles repo when nvim's config is stowed from it,
--- otherwise next to the nvim config.
local function default_doc_path()
  -- stow symlinks ~/.config/nvim into the repo, and resolve() can hand back a
  -- relative target, so normalise to an absolute path before walking up
  local config = vim.fn.fnamemodify(vim.fn.resolve(vim.fn.stdpath "config"), ":p"):gsub("/$", "")
  local repo = vim.fn.fnamemodify(config, ":h:h:h")
  if vim.fn.filereadable(repo .. "/install.sh") == 1 then
    return repo .. "/docs/KEYMAPS.md"
  end
  return config .. "/KEYMAPS.md"
end

function M.register_commands()
  local keymaps = require "keymaps"

  vim.api.nvim_create_user_command("Keymaps", function(args)
    local preset = args.args ~= "" and args.args or keymaps.preset_name()
    local ok, lines = pcall(render_preset, preset)
    if not ok then
      vim.notify("keymaps: " .. tostring(lines), vim.log.levels.ERROR)
      return
    end
    show_float(lines)
  end, {
    nargs = "?",
    desc = "Show the keybinding table (Linux + macOS columns)",
    complete = function()
      return keymaps.available()
    end,
  })

  vim.api.nvim_create_user_command("KeymapsWrite", function(args)
    local path = args.args ~= "" and vim.fn.expand(args.args) or default_doc_path()
    vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
    local ok, err = pcall(vim.fn.writefile, M.render_all(), path)
    if ok then
      vim.notify("keymaps: wrote " .. path, vim.log.levels.INFO)
    else
      vim.notify("keymaps: could not write " .. path .. " — " .. tostring(err), vim.log.levels.ERROR)
    end
  end, { nargs = "?", complete = "file", desc = "Write the keymap table to a Markdown file" })
end

return M
