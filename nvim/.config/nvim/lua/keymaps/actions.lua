-- Action registry.
--
-- An action is *what* a key does. It never says *which* key triggers it — that
-- lives in lua/keymaps/presets/<preset>.lua. Keeping the two apart makes presets
-- (default / jetbrains / vscode) and per-OS overrides possible without
-- duplicating any implementation.
--
-- Each entry:
--   desc   string    shown by which-key and in the generated table (required)
--   rhs    string|fn what the key does (required)
--   mode   string|table  default mode(s); a binding may override it
--   scope  "global" applied once at startup                        (default)
--          "lsp"    applied buffer-locally from the LspAttach hook
--          "git"    applied buffer-locally when gitsigns attaches
--   opts   table     extra vim.keymap.set options (e.g. remap = true)

local function cmd(command)
  return "<cmd>" .. command .. "<CR>"
end

--- Call `require(module).path(...)` lazily, warning instead of erroring when the
--- plugin is absent. Keeps a missing plugin from breaking an unrelated keymap.
local function call(module, path, ...)
  local args = { ... }
  return function()
    local ok, mod = pcall(require, module)
    if not ok then
      vim.notify(("keymaps: plugin '%s' is not available"):format(module), vim.log.levels.WARN)
      return
    end
    local target = mod
    for part in path:gmatch "[^.]+" do
      target = target[part]
      if target == nil then
        vim.notify(("keymaps: %s.%s is missing"):format(module, path), vim.log.levels.WARN)
        return
      end
    end
    return target(unpack(args))
  end
end

-- gitsigns renamed next_hunk/prev_hunk to nav_hunk; support both.
local function gs_nav(direction)
  return function()
    if vim.wo.diff then
      vim.cmd("normal! " .. (direction == "next" and "]c" or "[c"))
      return
    end
    local ok, gs = pcall(require, "gitsigns")
    if not ok then
      return
    end
    if gs.nav_hunk then
      gs.nav_hunk(direction)
    elseif direction == "next" then
      gs.next_hunk()
    else
      gs.prev_hunk()
    end
  end
end

-- stage/reset take a line range in visual mode and the hunk under the cursor otherwise.
local function gs_range(name)
  return function()
    local ok, gs = pcall(require, "gitsigns")
    if not ok then
      return
    end
    local mode = vim.fn.mode()
    if mode == "v" or mode == "V" then
      gs[name] { vim.fn.line ".", vim.fn.line "v" }
    else
      gs[name]()
    end
  end
end

--- Toggle a vim option and report the new value.
local function toggle(option)
  return function()
    vim.opt_local[option] = not vim.opt_local[option]:get()
  end
end

-- Remembers the pre-zoom window layout so <leader>z can restore it.
local zoom_state = {}

return {
  -- ── editor ────────────────────────────────────────────────────────────────
  ["editor.undo"] = { desc = "undo", rhs = "u" },
  ["editor.undo_insert"] = { desc = "undo", mode = "i", rhs = "<C-o>u" },
  ["editor.redo_insert"] = { desc = "redo", mode = "i", rhs = "<C-o><C-r>" },
  ["editor.debug_file"] = { desc = "debug focused file", rhs = call("ui.run_toolbar", "action", 9) },
  ["editor.redo"] = { desc = "redo", rhs = "<C-r>" },
  ["editor.save"] = { desc = "save file", mode = { "n", "i" }, rhs = cmd "write" },
  ["editor.copy_file"] = { desc = "copy whole file", rhs = cmd "%y+" },
  ["editor.clear_search"] = { desc = "clear search highlights", rhs = cmd "nohlsearch" },
  ["editor.command_mode"] = { desc = "enter command mode", rhs = ":" },
  ["editor.escape"] = { desc = "exit to normal mode", mode = { "i", "v" }, rhs = "<Esc>" },
  ["editor.format"] = {
    desc = "format buffer",
    mode = { "n", "x" },
    rhs = function()
      require("conform").format { lsp_format = "fallback" }
    end,
  },
  ["editor.comment"] = {
    desc = "toggle comment",
    mode = { "n", "x" },
    rhs = function()
      -- gc is an operator; gcc is the line variant. Pick per mode.
      return vim.fn.mode():match "^[vV\22]" and "gc" or "gcc"
    end,
    opts = { remap = true, expr = true },
  },
  ["editor.run_file"] = {
    desc = "run current file",
    rhs = function()
      return require("util.run").file()
    end,
  },
  ["editor.run_project"] = {
    desc = "run project",
    rhs = function()
      return require("util.run").project()
    end,
  },

  -- ── insert-mode movement ──────────────────────────────────────────────────
  ["insert.line_start"] = { desc = "go to line start", mode = "i", rhs = "<Esc>^i" },
  ["insert.line_end"] = { desc = "go to line end", mode = "i", rhs = "<End>" },
  ["insert.left"] = { desc = "move left", mode = "i", rhs = "<Left>" },
  ["insert.right"] = { desc = "move right", mode = "i", rhs = "<Right>" },
  ["insert.down"] = { desc = "move down", mode = "i", rhs = "<Down>" },
  ["insert.up"] = { desc = "move up", mode = "i", rhs = "<Up>" },

  -- ── windows ───────────────────────────────────────────────────────────────
  ["window.left"] = { desc = "go to left window", rhs = "<C-w>h" },
  ["window.right"] = { desc = "go to right window", rhs = "<C-w>l" },
  ["window.down"] = { desc = "go to window below", rhs = "<C-w>j" },
  ["window.up"] = { desc = "go to window above", rhs = "<C-w>k" },
  ["window.zoom"] = {
    desc = "toggle window zoom",
    rhs = function()
      local win = vim.api.nvim_get_current_win()
      if zoom_state[win] then
        vim.cmd(zoom_state[win])
        zoom_state[win] = nil
      else
        zoom_state[win] = vim.fn.winrestcmd()
        vim.cmd "wincmd |"
        vim.cmd "wincmd _"
      end
    end,
  },

  -- ── buffers ───────────────────────────────────────────────────────────────
  ["buffer.new"] = { desc = "new buffer", rhs = cmd "enew" },
  ["buffer.next"] = { desc = "next buffer", rhs = cmd "bnext" },
  ["buffer.prev"] = { desc = "previous buffer", rhs = cmd "bprevious" },
  ["buffer.close"] = { desc = "close buffer", rhs = cmd "bdelete" },
  ["buffer.recent_next"] = { desc = "switch to older recent buffer", mode = { "n", "i" }, rhs = call("ui.switcher", "cycle", "next") },
  ["buffer.recent_prev"] = { desc = "switch backward through recent buffers", mode = { "n", "i" }, rhs = call("ui.switcher", "cycle", "prev") },
  ["buffer.go_1"] = { desc = "go to buffer 1", rhs = call("ui.buffers", "go", 1) },
  ["buffer.go_2"] = { desc = "go to buffer 2", rhs = call("ui.buffers", "go", 2) },
  ["buffer.go_3"] = { desc = "go to buffer 3", rhs = call("ui.buffers", "go", 3) },
  ["buffer.go_4"] = { desc = "go to buffer 4", rhs = call("ui.buffers", "go", 4) },
  ["buffer.go_5"] = { desc = "go to buffer 5", rhs = call("ui.buffers", "go", 5) },
  ["buffer.go_6"] = { desc = "go to buffer 6", rhs = call("ui.buffers", "go", 6) },
  ["buffer.go_7"] = { desc = "go to buffer 7", rhs = call("ui.buffers", "go", 7) },
  ["buffer.go_8"] = { desc = "go to buffer 8", rhs = call("ui.buffers", "go", 8) },
  ["buffer.go_9"] = { desc = "go to buffer 9", rhs = call("ui.buffers", "go", 9) },
  ["ui.breadcrumbs"] = { desc = "browse current file path", rhs = call("ui.breadcrumbs", "pick") },
  ["ui.tools"] = { desc = "toggle bottom tools", rhs = call("ui.tools", "toggle") },

  -- ── ui ────────────────────────────────────────────────────────────────────
  ["ui.line_numbers"] = { desc = "toggle line numbers", rhs = toggle "number" },
  ["ui.relative_numbers"] = { desc = "toggle relative numbers", rhs = toggle "relativenumber" },
  ["ui.cheatsheet"] = { desc = "show cheatsheet", rhs = cmd "Cheatsheet" },
  ["ui.file_explorer"] = { desc = "toggle file explorer", rhs = call("ui.explorer", "toggle") },
  ["ui.theme"] = { desc = "preview / pick colorscheme", rhs = cmd "Theme", opts = { nowait = true } },
  ["ui.keymap_table"] = { desc = "show keymap table", rhs = cmd "Keymaps" },
  ["ui.whichkey_all"] = { desc = "show all keymaps", rhs = cmd "WhichKey" },
  ["ui.whichkey_query"] = {
    desc = "look up a keymap",
    rhs = function()
      vim.cmd("WhichKey " .. vim.fn.input "WhichKey: ")
    end,
  },

  -- ── markdown (buffer-local, applied on FileType markdown) ─────────────────
  ["markdown.render"] = {
    scope = "markdown",
    desc = "toggle in-buffer rendering",
    rhs = cmd "RenderMarkdown buf_toggle",
  },
  ["markdown.preview"] = {
    scope = "markdown",
    desc = "toggle browser preview",
    rhs = cmd "MarkdownPreviewToggle",
  },
  ["markdown.terminal"] = {
    scope = "markdown",
    desc = "render with mdcat in a split",
    rhs = function()
      local file = vim.fn.expand "%:p"
      if file == "" then
        vim.notify("markdown: buffer has no file yet", vim.log.levels.WARN)
        return
      end
      if vim.fn.executable "mdcat" == 0 then
        vim.notify("markdown: mdcat is not installed", vim.log.levels.ERROR)
        return
      end
      vim.cmd "botright new"
      -- deliberately no --paginate: a pager inside the terminal buffer would
      -- swallow Neovim's own scrollback and normal-mode navigation
      vim.fn.jobstart({ "mdcat", "--theme", "auto", file }, { term = true })
      vim.bo.buflisted = false
      vim.keymap.set("n", "q", "<cmd>bdelete!<CR>", { buffer = true, nowait = true, desc = "close preview" })
    end,
  },

  -- ── find / replace ────────────────────────────────────────────────────────
  ["find.spotlight"] = {
    desc = "spotlight search (ctrl-l/ctrl-h to switch category)",
    rhs = function() require("util.spotlight").open() end,
  },
  ["find.files"] = { desc = "find files", rhs = cmd "FzfLua files" },
  ["find.grep"] = { desc = "grep in project", rhs = cmd "FzfLua live_grep" },
  ["find.buffer"] = { desc = "find in buffer", rhs = cmd "FzfLua grep_curbuf" },
  ["find.replace"] = { desc = "find & replace in project", rhs = cmd "ReplaceProject" },
  ["find.replace_buffer"] = { desc = "find & replace in current buffer", rhs = cmd "Replace" },
  ["find.commands"] = {
    desc = "command palette",
    rhs = function()
      local ok, fzf = pcall(require, "fzf-lua")
      if not ok then
        vim.notify("keymaps: fzf-lua is not available", vim.log.levels.WARN)
        return
      end
      fzf.commands {
        actions = {
          ["enter"] = function(selected)
            if selected and #selected > 0 then
              vim.cmd(selected[1])
            end
          end,
        },
      }
    end,
  },

  -- ── terminal ──────────────────────────────────────────────────────────────
  ["terminal.escape"] = { desc = "leave terminal mode", mode = "t", rhs = "<C-\\><C-n>" },
  ["terminal.horizontal"] = {
    desc = "new horizontal terminal",
    rhs = call("util.terminal", "new", { pos = "sp" }),
  },
  ["terminal.vertical"] = {
    desc = "new vertical terminal",
    rhs = call("util.terminal", "new", { pos = "vsp" }),
  },
  ["terminal.toggle_horizontal"] = {
    desc = "toggle horizontal terminal",
    mode = { "n", "t" },
    rhs = call("util.terminal", "toggle", { pos = "sp", id = "htoggleTerm" }),
  },
  ["terminal.toggle_vertical"] = {
    desc = "toggle vertical terminal",
    mode = { "n", "t" },
    rhs = call("util.terminal", "toggle", { pos = "vsp", id = "vtoggleTerm" }),
  },
  ["terminal.toggle_float"] = {
    desc = "toggle floating terminal",
    mode = { "n", "t" },
    rhs = call("util.terminal", "toggle", { pos = "float", id = "floatTerm" }),
  },

  -- ── git (global) ──────────────────────────────────────────────────────────
  ["git.commits"] = { desc = "browse commits", rhs = cmd "FzfLua git_commits" },
  ["git.status"] = { desc = "git status", rhs = cmd "FzfLua git_status" },
  ["git.graph"] = { desc = "Git graph / workspace", rhs = call("ui.git", "open") },

  -- ── git (buffer-local, applied when gitsigns attaches) ────────────────────
  ["git.next_hunk"] = { scope = "git", desc = "next hunk", rhs = gs_nav "next" },
  ["git.prev_hunk"] = { scope = "git", desc = "previous hunk", rhs = gs_nav "prev" },
  ["git.preview_hunk"] = { scope = "git", desc = "preview hunk", rhs = call("gitsigns", "preview_hunk") },
  ["git.stage_hunk"] = { scope = "git", desc = "stage hunk", mode = { "n", "v" }, rhs = gs_range "stage_hunk" },
  ["git.reset_hunk"] = { scope = "git", desc = "reset hunk", mode = { "n", "v" }, rhs = gs_range "reset_hunk" },
  ["git.stage_buffer"] = { scope = "git", desc = "stage buffer", rhs = call("gitsigns", "stage_buffer") },
  ["git.undo_stage"] = { scope = "git", desc = "undo stage hunk", rhs = call("gitsigns", "undo_stage_hunk") },
  ["git.diff"] = { scope = "git", desc = "diff this", rhs = call("gitsigns", "diffthis") },
  ["git.diff_last"] = { scope = "git", desc = "diff against last commit", rhs = call("gitsigns", "diffthis", "~") },
  ["git.blame_line"] = { scope = "git", desc = "blame line (full)", rhs = call("gitsigns", "blame_line", { full = true }) },
  ["git.toggle_blame"] = { scope = "git", desc = "toggle inline blame", rhs = call("gitsigns", "toggle_current_line_blame") },
  ["git.toggle_deleted"] = { scope = "git", desc = "toggle deleted lines", rhs = call("gitsigns", "toggle_deleted") },

  -- ── lsp (buffer-local, applied on LspAttach) ──────────────────────────────
  ["lsp.declaration"] = { scope = "lsp", desc = "go to declaration", rhs = vim.lsp.buf.declaration },
  ["lsp.definition"] = { scope = "lsp", desc = "go to definition", rhs = vim.lsp.buf.definition },
  ["lsp.type_definition"] = { scope = "lsp", desc = "go to type definition", rhs = vim.lsp.buf.type_definition },
  ["lsp.references"] = { scope = "lsp", desc = "find references", rhs = cmd "FzfLua lsp_references" },
  ["lsp.implementations"] = { scope = "lsp", desc = "find implementations", rhs = cmd "FzfLua lsp_implementations" },
  ["lsp.hover"] = {
    scope = "lsp",
    desc = "hover documentation",
    rhs = function()
      vim.lsp.buf.hover { border = "rounded" }
    end,
  },
  ["lsp.signature"] = {
    scope = "lsp",
    desc = "signature help",
    rhs = function()
      vim.lsp.buf.signature_help { border = "rounded" }
    end,
  },
  ["lsp.code_action"] = { scope = "lsp", desc = "code action", mode = { "n", "v" }, rhs = vim.lsp.buf.code_action },
  ["lsp.rename"] = {
    scope = "lsp",
    desc = "rename symbol",
    rhs = vim.lsp.buf.rename,
  },
  ["lsp.diagnostics"] = { desc = "diagnostics to loclist", rhs = vim.diagnostic.setloclist },
  ["lsp.info"] = { scope = "lsp", desc = "lsp info", rhs = cmd "checkhealth vim.lsp" },
  ["lsp.restart"] = { scope = "lsp", desc = "restart lsp", rhs = cmd "LspRestart" },
  ["lsp.workspace_add"] = { scope = "lsp", desc = "add workspace folder", rhs = vim.lsp.buf.add_workspace_folder },
  ["lsp.workspace_remove"] = { scope = "lsp", desc = "remove workspace folder", rhs = vim.lsp.buf.remove_workspace_folder },
  ["lsp.workspace_list"] = {
    scope = "lsp",
    desc = "list workspace folders",
    rhs = function()
      vim.notify(vim.inspect(vim.lsp.buf.list_workspace_folders()))
    end,
  },

  -- ── debug ─────────────────────────────────────────────────────────────────
  ["debug.continue"] = { desc = "continue / start", rhs = call("dap", "continue") },
  ["debug.breakpoint"] = { desc = "toggle breakpoint", rhs = call("dap", "toggle_breakpoint") },
  ["debug.step_over"] = { desc = "step over", rhs = call("dap", "step_over") },
  ["debug.step_into"] = { desc = "step into", rhs = call("dap", "step_into") },
  ["debug.step_out"] = { desc = "step out", rhs = call("dap", "step_out") },
  ["debug.repl"] = { desc = "toggle repl", rhs = call("dap", "repl.toggle") },
  ["debug.run_last"] = { desc = "re-run last resolved debug launch", rhs = call("util.debug_session", "restart") },
  ["debug.ui"] = { desc = "toggle debug ui", rhs = call("ui.dap", "toggle") },
  ["debug.terminate"] = { desc = "terminate session", rhs = call("dap", "terminate") },
  ["debug.inspect"] = { desc = "inspect variable / expression", mode = { "n", "v" }, rhs = call("dapui", "eval") },
  ["debug.test"] = { desc = "debug nearest Go test", rhs = call("dap-go", "debug_test") },
  ["debug.test_last"] = { desc = "debug last Go test", rhs = call("dap-go", "debug_last_test") },

  -- ── go ────────────────────────────────────────────────────────────────────
  ["go.generate"] = { desc = "go generate", rhs = cmd "GoGenerate" },
  ["go.fill_struct"] = {
    desc = "go fill struct",
    rhs = function()
      vim.lsp.buf.code_action {
        filter = function(action) return action.title:lower():find("fill", 1, true) ~= nil end,
        apply = true,
      }
    end,
  },
}
