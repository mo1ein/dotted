-- A Go debug launch owns its package, even when another project is focused.
assert(vim.env.NVIM_TEST_ISOLATED == "1")
local root = vim.fn.tempname();vim.fn.mkdir(root,"p");root=assert(vim.uv.fs_realpath(root))
local a,b = root.."/go A",root.."/go B"
vim.fn.mkdir(a,"p");vim.fn.mkdir(b,"p")
vim.fn.writefile({"module rerun.test/a","go 1.23"},a.."/go.mod")
vim.fn.writefile({"package main",'import "fmt"',"func main() {"," value := helper()",' fmt.Println("GO_A",value)',"}"},a.."/main.go")
vim.fn.writefile({"package main","func helper() int { return 42 }"},a.."/helper.go")
vim.fn.writefile({"module rerun.test/b","go 1.23"},b.."/go.mod")
vim.fn.writefile({"package main","func main() {}"},b.."/other.go")
vim.cmd.edit(vim.fn.fnameescape(a.."/main.go"))
local dap = require "dap"
local stops=0
dap.listeners.after.event_stopped.go_rerun_test=function() stops=stops+1 end
vim.api.nvim_win_set_cursor(0,{5,0});dap.toggle_breakpoint()
require("ui.run_toolbar").action(9)
local function stopped(previous)
  assert(vim.wait(45000,function()
    local s=dap.session()
    return stops>previous and s and s.stopped_thread_id and s.current_frame and s.current_frame.scopes
  end,20),"Go didn't stop at original breakpoint")
  local s=dap.session()
  assert(s.config.program==a and s.config.cwd==a,vim.inspect(s.config))
  assert(s.current_frame.source.path==a.."/main.go",vim.inspect(s.current_frame))
end
stopped(0)
vim.cmd.tabnew(vim.fn.fnameescape(b.."/other.go"))
local other_tab=vim.api.nvim_get_current_tabpage()
vim.cmd.lcd(vim.fn.fnameescape(b))
local previous=stops
require("ui.run_toolbar").action(7)
stopped(previous)
dap.continue()
assert(vim.wait(15000,function() return dap.session()==nil end,20),"Go didn't exit")
assert(require("ui.run_toolbar").mode=="debug")
vim.api.nvim_set_current_tabpage(other_tab)
vim.bo.filetype="python"
previous=stops
require("ui.run_toolbar").action(7)
stopped(previous)
dap.terminate()
assert(vim.wait(15000,function() return dap.session()==nil end,20))
assert(vim.v.errmsg=="",vim.v.errmsg)
print "Go rerun: current-package debug includes helper files; active and completed reruns retain package/cwd after switching projects and filetypes"
