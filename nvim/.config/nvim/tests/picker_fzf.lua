-- Real fzf integration: previews, smaller viewport, confirmation, and config save.
-- Run after plugins are installed, with fzf on PATH and isolated XDG directories.
local loader = require "config.theme_loader"
assert(vim.env.NVIM_TEST_ISOLATED == "1", "Picker tests require isolated XDG dirs and NVIM_TEST_ISOLATED=1")
local selection = require "themes.selection"
local previous_choice = selection.read()
assert(vim.fn.executable "fzf" == 1, "This integration test requires fzf")
loader.apply("dotted-onedark")
local original = loader.current()
local function job()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].filetype == "fzf" and vim.b[buf].terminal_job_id then return vim.b[buf].terminal_job_id end
  end
end
local function open()
  loader.pick()
  assert(vim.wait(5000, function() return job() ~= nil end, 20), "fzf terminal did not open")
  assert(vim.api.nvim_win_get_height(0) <= math.ceil(vim.o.lines * 0.425), "Picker is taller than the requested half-height")
  -- Let fzf finish its initial RPC preview before sending a navigation key.
  vim.wait(300)
  vim.api.nvim_chan_send(job(), "\27[B")
  assert(vim.wait(5000, function() return loader.current() ~= original end, 20), "Highlighting a row did not preview its theme")
  return job(), loader.current()
end
local channel = open()
vim.api.nvim_chan_send(channel, "\27")
assert(vim.wait(5000, function() return not job() and loader.current() == original end, 20), "Escape did not close and restore")
assert(selection.read() == previous_choice, "Preview/Escape unexpectedly saved a theme")

local function dialog()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "theme-confirm" then return win end
  end
end
channel = open()
vim.api.nvim_chan_send(channel, "\r")
assert(vim.wait(5000, function() return dialog() ~= nil end, 20), "Enter did not open the confirmation box")
assert(selection.read() == previous_choice, "Theme saved before confirmation")
vim.fn.maparg("n", "n", false, true).callback()
assert(loader.current() == original and selection.read() == previous_choice, "No didn't restore without saving")

local picked
channel, picked = open()
vim.api.nvim_chan_send(channel, "\r")
assert(vim.wait(5000, function() return dialog() ~= nil end, 20))
vim.wait(200)
assert(loader.current() == picked and selection.read() == previous_choice, "Pending confirmation was canceled or saved by fzf on_close")
vim.fn.maparg("y", "n", false, true).callback()
assert(not dialog() and selection.read() == picked and loader.current() == picked, "Yes didn't save the confirmed theme in config")
assert(vim.v.errmsg == "", vim.v.errmsg)
print "fzf integration: smaller picker, preview, Escape/No restore, confirmation and config persistence passed"
vim.cmd "qa!"
