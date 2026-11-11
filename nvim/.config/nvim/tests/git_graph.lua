-- Actual Neogit graph and commit navigation, only in a disposable repository.
assert(vim.env.NVIM_TEST_ISOLATED == "1")
assert(not package.loaded.neogit, "Neogit loaded at startup")
local directory = vim.fn.tempname() .. " git graph"
vim.fn.mkdir(directory, "p")
directory = assert(vim.uv.fs_realpath(directory))
local function git(...)
  local args = { "git", "-C", directory, "-c", "user.name=UI Test", "-c", "user.email=test@example.invalid", "-c", "commit.gpgsign=false" }
  vim.list_extend(args, { ... })
  local result = vim.system(args, { text = true }):wait(15000)
  assert(result.code == 0, result.stderr)
  return vim.trim(result.stdout)
end
git("init", "-b", "main")
vim.fn.writefile({ "root" }, directory .. "/main.txt")
git("add", ".")
git("commit", "-m", "root commit")
git("checkout", "-b", "feature")
vim.fn.writefile({ "feature" }, directory .. "/feature.txt")
git("add", ".")
git("commit", "-m", "feature commit")
git("checkout", "main")
vim.fn.writefile({ "main" }, directory .. "/other.txt")
git("add", ".")
git("commit", "-m", "main commit")
git("merge", "--no-ff", "feature", "-m", "merge feature")
git("tag", "test-tag")
vim.fn.writefile({ "dirty working file" }, directory .. "/main.txt")
local before, head = git("status", "--porcelain"), git("rev-parse", "HEAD")
vim.cmd.edit(vim.fn.fnameescape(directory .. "/main.txt"))
local started = vim.uv.hrtime()
require("ui.git").open()
local graph
assert(vim.wait(15000, function()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].filetype == "NeogitLogView" then
      local lines = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
      if lines:find("merge feature", 1, true) and lines:find("feature commit", 1, true) then graph = buf; return true end
    end
  end
  return false
end, 20), "Neogit didn't show the merge/branch graph")
local ms = (vim.uv.hrtime() - started) / 1e6
assert(require("neogit.config").values.graph_style == "unicode")
assert(git("status", "--porcelain") == before and git("rev-parse", "HEAD") == head, "Opening graph changed the repository")
local lines = vim.api.nvim_buf_get_lines(graph, 0, -1, false)
local row
for i, line in ipairs(lines) do if line:find("feature commit", 1, true) then row = i; break end end
assert(row)
local win = vim.fn.win_findbuf(graph)[1]
vim.api.nvim_set_current_win(win)
vim.api.nvim_win_set_cursor(win, { row, 0 })
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), "xt", false)
assert(vim.wait(10000, function()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do if vim.bo[buf].filetype == "NeogitCommitView" then return true end end
  return false
end, 20), "Enter didn't open commit details")
assert(git("status", "--porcelain") == before and git("rev-parse", "HEAD") == head, "Commit inspection changed the repository")
assert(vim.v.errmsg == "", vim.v.errmsg)
print(("Git graph: lazy load, branches/merge/tag history, commit details and dirty-worktree safety passed; first graph %.0f ms"):format(ms))
