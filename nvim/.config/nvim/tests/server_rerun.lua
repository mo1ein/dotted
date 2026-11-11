-- A server must release its port before the replacement process starts.
assert(vim.env.NVIM_TEST_ISOLATED == "1")
local dir=vim.fn.tempname();vim.fn.mkdir(dir,"p");dir=assert(vim.uv.fs_realpath(dir))
local tcp=assert(vim.uv.new_tcp());assert(tcp:bind("127.0.0.1",0));local port=tcp:getsockname().port;tcp:close()
local file=dir.."/server.py"
vim.fn.writefile({
  "import signal,socket,sys,time,os",
  "def stop(*args):",
  "    time.sleep(.25)",
  "    sys.exit(0)",
  "signal.signal(signal.SIGTERM,stop)",
  "signal.signal(signal.SIGHUP,stop)",
  "sock=socket.socket()",
  "sock.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1)",
  "sock.bind(('127.0.0.1',"..port.."))",
  "sock.listen()",
  "print('SERVER_READY',os.getpid(),flush=True)",
  "time.sleep(60)",
},file)
vim.cmd.edit(vim.fn.fnameescape(file))
local task=require("util.run").file()
local function ready(previous)
  assert(vim.wait(10000,function()
    local job=task.strategy.job_id
    local buf=task:get_bufnr()
    return task:is_running() and job and job~=previous and buf
      and table.concat(vim.api.nvim_buf_get_lines(buf,0,-1,false),""):find("SERVER_READY",1,true)~=nil
  end,10),"Replacement server didn't acquire original port: "..vim.inspect(vim.api.nvim_buf_get_lines(task:get_bufnr(),0,-1,false)))
end
ready(nil)
local original=task.strategy.job_id
vim.cmd.tabnew();vim.api.nvim_buf_set_name(0,dir.."/other.py")
vim.api.nvim_buf_set_lines(0,0,-1,false,{"print('OTHER_PROJECT')"})
local before=vim.uv.hrtime()
require("ui.run_toolbar").action(7)
local handler_ms=(vim.uv.hrtime()-before)/1e6
assert(handler_ms<200,"Restart blocked editor during shutdown: "..handler_ms)
ready(original)
assert(task.cmd[2]==file,"Server restart changed target")
-- Stop also cancels a restart which is waiting for graceful shutdown.
original=task.strategy.job_id
require("ui.run_toolbar").action(7)
require("ui.output").stop()
assert(vim.wait(10000,function() return vim.fn.jobwait({original},0)[1]~=-1 end,10))
assert(not task:is_running() and not task.strategy.job_id,"Stop didn't cancel pending restart")
assert(vim.v.errmsg=="",vim.v.errmsg)
print(("Server rerun: graceful same-port restart across tabs, responsive shutdown wait (%.0fms handler), and cancellation by Stop passed"):format(handler_ms))
