local map = vim.keymap.set

map("i", "<C-b>", "<ESC>^i", { desc = "move beginning of line" })
map("i", "<C-e>", "<End>", { desc = "move end of line" })
map("i", "<C-h>", "<Left>", { desc = "move left" })
map("i", "<C-l>", "<Right>", { desc = "move right" })
map("i", "<C-j>", "<Down>", { desc = "move down" })
map("i", "<C-k>", "<Up>", { desc = "move up" })

map("n", "<C-h>", "<C-w>h", { desc = "switch window left" })
map("n", "<C-l>", "<C-w>l", { desc = "switch window right" })
map("n", "<C-j>", "<C-w>j", { desc = "switch window down" })
map("n", "<C-k>", "<C-w>k", { desc = "switch window up" })

map("n", "<Esc>", "<cmd>noh<CR>", { desc = "general clear highlights" })

map("n", "<C-s>", "<cmd>w<CR>", { desc = "general save file" })
map("n", "<C-c>", "<cmd>%y+<CR>", { desc = "general copy whole file" })

map("n", "<leader>n", "<cmd>set nu!<CR>", { desc = "toggle line number" })
map("n", "<leader>rn", "<cmd>set rnu!<CR>", { desc = "toggle relative number" })
map("n", "<leader>ch", "<cmd>NvCheatsheet<CR>", { desc = "toggle nvcheatsheet" })

map({ "n", "x" }, "<leader>fm", function()
    require("conform").format { lsp_fallback = true }
end, { desc = "general format file" })

-- global lsp mappings
map("n", "<leader>ds", vim.diagnostic.setloclist, { desc = "LSP diagnostic loclist" })

-- tabufline
map("n", "<leader>b", "<cmd>enew<CR>", { desc = "buffer new" })

map("n", "<tab>", function()
    require("nvchad.tabufline").next()
end, { desc = "buffer goto next" })

map("n", "<S-tab>", function()
    require("nvchad.tabufline").prev()
end, { desc = "buffer goto prev" })

map("n", "<leader>x", function()
    require("nvchad.tabufline").close_buffer()
end, { desc = "buffer close" })

-- Comment
map("n", "<leader>/", "gcc", { desc = "toggle comment", remap = true })
map("v", "<leader>/", "gc", { desc = "toggle comment", remap = true })
map("n", "<C-_>", "gcc", { desc = "toggle comment", remap = true })
map("v", "<C-_>", "gc", { desc = "toggle comment", remap = true })

-- nvimtree
map("n", "<leader>e", "<cmd>NvimTreeToggle<CR>", { desc = "nvimtree toggle window" })

-- terminal
map("t", "<C-x>", "<C-\\><C-N>", { desc = "terminal escape terminal mode" })

-- new terminals
map("n", "<leader>h", function()
    require("nvchad.term").new { pos = "sp" }
end, { desc = "terminal new horizontal term" })

map("n", "<leader>v", function()
    require("nvchad.term").new { pos = "vsp" }
end, { desc = "terminal new vertical term" })

-- toggleable
map({ "n", "t" }, "<A-v>", function()
    require("nvchad.term").toggle { pos = "vsp", id = "vtoggleTerm" }
end, { desc = "terminal toggleable vertical term" })

map({ "n", "t" }, "<A-h>", function()
    require("nvchad.term").toggle { pos = "sp", id = "htoggleTerm" }
end, { desc = "terminal toggleable horizontal term" })

map({ "n", "t" }, "<A-i>", function()
    require("nvchad.term").toggle { pos = "float", id = "floatTerm" }
end, { desc = "terminal toggle floating term" })

-- whichkey
map("n", "<leader>wK", "<cmd>WhichKey <CR>", { desc = "whichkey all keymaps" })

map("n", "<leader>wk", function()
    vim.cmd("WhichKey " .. vim.fn.input "WhichKey: ")
end, { desc = "whichkey query lookup" })

-- add yours here

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")
map("v", "jk", "<ESC>", { desc = "exit visual mode" })

-- fzf-lua mappings
map("n", "<leader>fg", "<cmd>FzfLua live_grep<CR>", { desc = "fzf-lua live grep" })
map("n", "<leader>ff", "<cmd>FzfLua files<CR>", { desc = "fzf-lua find files" })
map("n", "<leader>fz", "<cmd>FzfLua grep_curbuf<CR>", { desc = "fzf-lua find in current buffer" })
map("n", "<leader>gc", "<cmd>FzfLua git_commits<CR>", { desc = "fzf-lua git commits" })
map("n", "<leader>gt", "<cmd>FzfLua git_status<CR>", { desc = "fzf-lua git status" })

-- command palette (immediate execution, no preview)
map("n", "<leader>p", function()
  local ok, fzf = pcall(require, "fzf-lua")
  if not ok then return end
  fzf.commands({
    actions = {
      ["enter"] = function(selected)
        if selected and #selected > 0 then
          vim.cmd(selected[1])
        end
      end,
    },
  })
end, { desc = "command palette" })

-- search & replace (defined in plugins/init.lua via keys)

-- debugging
map("n", "<leader>dc", function() require("dap").continue() end, { desc = "DAP: continue" })
map("n", "<leader>db", function() require("dap").toggle_breakpoint() end, { desc = "DAP: toggle breakpoint" })
map("n", "<leader>do", function() require("dap").step_over() end, { desc = "DAP: step over" })
map("n", "<leader>di", function() require("dap").step_into() end, { desc = "DAP: step into" })
map("n", "<leader>dO", function() require("dap").step_out() end, { desc = "DAP: step out" })
map("n", "<leader>dr", function() require("dap").repl.toggle() end, { desc = "DAP: toggle repl" })
map("n", "<leader>dl", function() require("dap").run_last() end, { desc = "DAP: run last" })
map("n", "<leader>du", function() require("dapui").toggle() end, { desc = "DAP: toggle UI" })
map("n", "<leader>dx", function() require("dap").terminate() end, { desc = "DAP: terminate" })

-- go development
map("n", "<leader>gg", "<cmd>GoGenerate<CR>", { desc = "go: generate" })
map("n", "<leader>gf", "<cmd>GoFillStruct<CR>", { desc = "go: fill struct" })

-- pane zoom (maximize/restore current split)
local zoom_state = {}
map("n", "<leader>z", function()
  local win = vim.api.nvim_get_current_win()
  if zoom_state[win] then
    vim.cmd(zoom_state[win])
    zoom_state[win] = nil
  else
    zoom_state[win] = vim.api.nvim_win_call(win, function()
      return vim.fn.winrestcmd()
    end)
    vim.cmd("wincmd |")
    vim.cmd("wincmd _")
  end
end, { desc = "toggle pane zoom" })

-- vim-go
-- map("n", "<leader>gr", "<cmd>GoRun<CR>",{desc="go run"})

-- todo
-- map("n", "<leader>fh", "<cmd>Telescope help_tags<CR>", { desc = "telescope help page" })

-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")
--

---- Run current file based on filetype (extension or detected syntax)
local function run_file()
    local ft = vim.bo.filetype
    local filename = vim.fn.expand "%"
    if filename == "" then
        print "No file name to run"
        return
    end

    -- Save the file before running (optional but recommended)
    vim.cmd "write"

    if ft == "markdown" then
        if vim.fn.exists ":MarkdownPreview" == 2 then
            vim.cmd "MarkdownPreview"
        end
    elseif ft == "go" then
        if vim.fn.exists ":GoRun" == 2 then
            vim.cmd "GoRun"
        else
            vim.cmd "!go run %"
        end
    elseif ft == "python" then
        -- first check uv for
        local function is_uv_project()
            local cwd = vim.fn.getcwd()
            return vim.fn.filereadable(cwd .. "/uv.lock") == 1
                or vim.fn.filereadable(cwd .. "/uv.toml") == 1
                or vim.fn.filereadable(cwd .. "/pyproject.toml") == 1
        end
        local runner = is_uv_project() and "!uv run %" or "!python %"
        vim.cmd(runner)
    elseif ft == "tex" then
        -- todo: add vimtexView
        -- Prefer VimtexCompile if you use vimtex, else fallback to latexmk
        if vim.fn.exists ":VimtexCompile" == 2 then
            vim.cmd "VimtexCompile"
        else
            vim.cmd "!latexmk -pdf -interaction=nonstopmode %"
        end
    elseif ft == "sh" or ft == "bash" or ft == "zsh" then
        vim.cmd "!bash %"
    elseif ft == "lua" then
        vim.cmd "!lua %"
    elseif ft == "javascript" or ft == "typescript" then
        vim.cmd "!node %"
    elseif ft == "rust" then
        -- Assumes cargo project; otherwise use rustc
        vim.cmd "!cargo run"
    elseif ft == "c" then
        -- Simple compile+run (adjust compiler flags as needed)
        local out = vim.fn.expand "%:r" -- basename without extension
        vim.cmd("!gcc " .. filename .. " -o " .. out .. " && ./" .. out)
    elseif ft == "cpp" then
        local out = vim.fn.expand "%:r"
        vim.cmd("!g++ " .. filename .. " -o " .. out .. " && ./" .. out)
    else
        print("No run command defined for filetype: " .. ft)
    end
end

vim.keymap.set("n", "<leader>r", run_file, { desc = "Run current file based on filetype" })
