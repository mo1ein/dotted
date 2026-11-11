-- JetBrains "Search Everywhere"-style spotlight: one fzf-lua window that
-- stays open while arrow keys / ctrl-l/ctrl-h cycle categories in place
-- (like pulse.nvim). Switching is pure native fzf: execute-silent bumps a
-- plain-text index file via a tiny shell script, reload cats the matching
-- pre-rendered category file. No Lua callback runs on the hot path, since
-- fzf-lua's Lua-callback reload mechanism round-trips through a socket RPC
-- into Neovim on every keypress -- fine for occasional actions, but
-- noticeably laggy for something you expect to feel instant.
--
-- Grep is the one exception: live grep needs fzf's disabled-fuzzy-match,
-- reload-every-keystroke mode, which can't coexist with the other
-- categories' normal fuzzy-filtered static lists in the same fzf process.
-- Selecting it opens the real dedicated live_grep picker instead.

local M = {}

--- @type { key: string, label: string, generate: fun():string[], accept: fun(line:string) }[]
M.categories = {
  {
    key = "f",
    label = "Files",
    -- prefetched async in M.open(); this is only the fallback if that
    -- hasn't landed yet by the time this category is generated.
    async_cmd = { "git", "ls-files", "--cached", "--others", "--exclude-standard" },
    generate = function()
      local out = vim.fn.systemlist { "git", "ls-files", "--cached", "--others", "--exclude-standard" }
      if vim.v.shell_error ~= 0 then
        out = vim.fn.systemlist { "find", ".", "-type", "f", "-not", "-path", "*/.git/*" }
      end
      return out
    end,
    accept = function(line) vim.cmd.edit(vim.fn.fnameescape(line)) end,
  },
  {
    key = "b",
    label = "Buffers",
    generate = function()
      local out = {}
      for _, b in ipairs(vim.fn.getbufinfo { buflisted = 1 }) do
        out[#out + 1] = string.format("%d\t%s", b.bufnr, vim.fn.fnamemodify(b.name, ":~:."))
      end
      return out
    end,
    accept = function(line)
      local bufnr = tonumber(line:match "^(%d+)")
      if bufnr then vim.cmd.buffer(bufnr) end
    end,
  },
  {
    key = "r",
    label = "Recent",
    generate = function()
      return vim.tbl_filter(function(f) return vim.fn.filereadable(f) == 1 end, vim.v.oldfiles)
    end,
    accept = function(line) vim.cmd.edit(vim.fn.fnameescape(line)) end,
  },
  {
    key = "g",
    label = "Grep",
    generate = function() return { "<press enter to start live grep>" } end,
    accept = function() vim.schedule(function() require("fzf-lua").live_grep() end) end,
  },
  {
    key = "c",
    label = "Commands",
    generate = function()
      local out = {}
      for name in pairs(vim.api.nvim_get_commands {}) do
        out[#out + 1] = name
      end
      for name in pairs(vim.api.nvim_buf_get_commands(0, {})) do
        out[#out + 1] = name
      end
      table.sort(out)
      return out
    end,
    accept = function(line) vim.cmd(line) end,
  },
  {
    key = "k",
    label = "Keymaps",
    generate = function()
      local out, seen = {}, {}
      for _, mode in ipairs { "n", "i", "v", "x" } do
        for _, m in ipairs(vim.api.nvim_get_keymap(mode)) do
          local line = string.format("%s\t%s\t%s", mode, m.lhs, m.desc or m.rhs or "")
          if not seen[line] then
            seen[line] = true
            out[#out + 1] = line
          end
        end
      end
      return out
    end,
    accept = function(line)
      local mode, lhs = line:match "^(%S+)\t(%S+)"
      if mode and lhs then
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(lhs, true, true, true), mode, true)
      end
    end,
  },
  {
    key = "p",
    label = "Help",
    generate = function() return vim.fn.getcompletion("", "help") end,
    accept = function(line) vim.cmd.help(line) end,
  },
  {
    key = "d",
    label = "Diagnostics",
    generate = function()
      local out = {}
      for _, d in ipairs(vim.diagnostic.get()) do
        local fname = vim.api.nvim_buf_get_name(d.bufnr)
        out[#out + 1] = string.format("%s:%d:%s", vim.fn.fnamemodify(fname, ":~:."), d.lnum + 1, d.message:gsub("\n", " "))
      end
      return out
    end,
    accept = function(line)
      local fname, lnum = line:match "^(.-):(%d+):"
      if fname then
        vim.cmd.edit(vim.fn.fnameescape(fname))
        vim.api.nvim_win_set_cursor(0, { tonumber(lnum), 0 })
      end
    end,
  },
  {
    key = "s",
    label = "Git Status",
    async_cmd = { "git", "status", "--porcelain" },
    generate = function() return vim.fn.systemlist { "git", "status", "--porcelain" } end,
    accept = function(line)
      local fname = line:match "^..%s+(.+)$"
      if fname then vim.cmd.edit(vim.fn.fnameescape(fname)) end
    end,
  },
  {
    key = "m",
    label = "Marks",
    generate = function()
      local out = {}
      for _, m in ipairs(vim.fn.getmarklist()) do
        out[#out + 1] = string.format("%s\t%s:%d", m.mark, m.file or vim.fn.bufname(m.pos[1]), m.pos[2])
      end
      return out
    end,
    accept = function(line)
      local mark = line:match "^(%S+)"
      if mark then vim.cmd("normal! `" .. mark:sub(2)) end
    end,
  },
}

--- Regenerate the shared entries file for category `idx`, tagging each line.
-- ANSI SGR codes for the pill-style active tab. fzf-lua's `--ansi` is on by
-- default, so these render as real colors rather than literal escape text.
-- Plain color blocks (no Nerd Font glyphs needed) so this renders correctly
-- regardless of the terminal's font.
local ESC = string.char(27)
local RESET = ESC .. "[0m"
local PILL = ESC .. "[48;5;240m" .. ESC .. "[97m" .. ESC .. "[1m" -- bold white on gray
local DIM = ESC .. "[90m" -- muted gray for inactive labels

--- One-line "you are here" bar: every category listed, active one rendered
--- as a colored pill button instead of plain brackets.
--- @param idx integer
--- @return string
function M.mode_bar(idx)
  local parts = {}
  for i, cat in ipairs(M.categories) do
    if i == idx then
      parts[#parts + 1] = PILL .. "  " .. cat.label .. "  " .. RESET
    else
      parts[#parts + 1] = DIM .. cat.label .. RESET
    end
  end
  return table.concat(parts, "  ") .. "  " .. DIM .. "(ctrl-l/ctrl-h to switch)" .. RESET
end

--- Render the tagged lines (pinned mode-bar on line 1, via --header-lines=1,
--- followed by that category's tagged entries) for category `idx`. `cache`,
--- when given, is reused instead of re-running git/help-tags/etc.
--- @param idx integer
--- @param cache table<integer, string[]>?
--- @return string[]
function M.render_lines(idx, cache)
  local cat = M.categories[idx]
  local lines = cache and cache[idx]
  if not lines then
    local ok, result = pcall(cat.generate)
    lines = ok and result or { "error generating entries: " .. tostring(result) }
    if cache then
      cache[idx] = lines
    end
  end
  local tagged = { M.mode_bar(idx) }
  for _, line in ipairs(lines) do
    tagged[#tagged + 1] = string.format("[%s] %s", cat.label, line)
  end
  if #tagged == 1 then
    tagged[#tagged + 1] = string.format("[%s] (nothing here)", cat.label)
  end
  return tagged
end

--- Write category `idx`'s rendered lines to its dedicated file under `dir`.
--- @param dir string
--- @param idx integer
--- @param cache table<integer, string[]>?
function M.write_category_file(dir, idx, cache)
  vim.fn.writefile(M.render_lines(idx, cache), dir .. "/" .. idx)
end

--- Strip the "[Label] " tag off a result line.
--- @param tagged_line string
--- @return string
function M.strip_tag(tagged_line)
  return (tagged_line:gsub("^%[[^%]]+%]%s?", ""))
end

--- @param idx integer current 1-based index
--- @param delta integer +1 or -1
--- @return integer next 1-based index, wrapping around
function M.next_index(idx, delta)
  local n = #M.categories
  return ((idx - 1 + delta) % n) + 1
end

--- Populate every category's file under `dir` for a fresh session: cheap
--- pure-Lua/API categories are written immediately; `async_cmd` ones get an
--- instant "(loading...)" placeholder, then get overwritten in place once
--- vim.system's real result lands. Help is skipped here (left lazy) since
--- Neovim caches its help-tag scan internally after first use anyway.
--- @param dir string
--- @param cache table<integer, string[]>
function M.populate_files(dir, cache)
  for i, cat in ipairs(M.categories) do
    if cat.async_cmd then
      vim.fn.writefile({ M.mode_bar(i), string.format("[%s] (loading...)", cat.label) }, dir .. "/" .. i)
      vim.system(cat.async_cmd, { text = true }, function(res)
        vim.schedule(function()
          cache[i] = vim.split(res.stdout or "", "\n", { trimempty = true })
          M.write_category_file(dir, i, cache)
        end)
      end)
    else
      M.write_category_file(dir, i, cache)
    end
  end
end

--- Build the tiny shell scripts that do all category switching natively in
--- fzf, with zero Lua/RPC round-trip per keypress: next.sh/prev.sh bump a
--- plain-text 1-based index file (wrapping, with the +n trick to keep shell
--- arithmetic's modulo from ever going negative), show.sh cats the matching
--- pre-rendered file. `%s` for shellescape below avoids the escaping
--- headaches of embedding this logic directly in fzf's --bind string.
--- @param dir string
--- @param state_file string
--- @param n integer number of categories
function M.write_switch_scripts(dir, state_file, n)
  local st = vim.fn.shellescape(state_file)
  vim.fn.writefile({
    "#!/bin/sh",
    string.format("i=$(cat %s)", st),
    string.format("echo $(( i %% %d + 1 )) > %s", n, st),
  }, dir .. "/next.sh")
  vim.fn.writefile({
    "#!/bin/sh",
    string.format("i=$(cat %s)", st),
    string.format("echo $(( (i - 2 + %d) %% %d + 1 )) > %s", n, n, st),
  }, dir .. "/prev.sh")
  vim.fn.writefile({
    "#!/bin/sh",
    string.format("i=$(cat %s)", st),
    string.format("cat %s/$i", vim.fn.shellescape(dir)),
  }, dir .. "/show.sh")
end

--- Open the single spotlight window, starting on category `idx` (default: Files).
--- @param idx integer?
function M.open(idx)
  idx = idx or 1
  local n = #M.categories
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  local state_file = dir .. "/state"
  vim.fn.writefile({ tostring(idx) }, state_file)

  local cache = {}
  M.populate_files(dir, cache)
  M.write_switch_scripts(dir, state_file, n)

  local function esc(s) return vim.fn.shellescape(s) end
  local next_sh, prev_sh, show_sh = esc(dir .. "/next.sh"), esc(dir .. "/prev.sh"), esc(dir .. "/show.sh")
  local next_action = string.format("execute-silent(sh %s)+reload(sh %s)", next_sh, show_sh)
  local prev_action = string.format("execute-silent(sh %s)+reload(sh %s)", prev_sh, show_sh)

  require("fzf-lua").fzf_exec("cat " .. esc(dir .. "/" .. idx), {
    prompt = "spotlight> ",
    fzf_opts = { ["--header-lines"] = "1" },
    -- fzf_exec drops fzf_opts["--bind"] entirely; opts.keymap.fzf is the
    -- API it actually merges additively with its own default binds.
    keymap = {
      fzf = {
        ["ctrl-l"] = next_action,
        ["ctrl-h"] = prev_action,
        ["right"] = next_action,
        ["left"] = prev_action,
      },
    },
    actions = {
      ["default"] = function(selected)
        if selected and selected[1] then
          local cur = tonumber(vim.fn.readfile(state_file)[1]) or idx
          M.categories[cur].accept(M.strip_tag(selected[1]))
        end
      end,
    },
  })
end

return M
