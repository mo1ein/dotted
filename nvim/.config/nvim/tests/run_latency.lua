-- Measure launch-handler latency separately from interpreter/compiler startup.
assert(vim.env.NVIM_TEST_ISOLATED == "1")
local dir = vim.fn.tempname()
vim.fn.mkdir(dir, "p")
local file = dir .. "/latency.py"
vim.fn.writefile({ "print('LAUNCH_LATENCY_READY', flush=True)" }, file)
vim.cmd.edit(vim.fn.fnameescape(file))
local source = vim.api.nvim_get_current_win()
local timings = {}
for i = 1, 3 do
  vim.api.nvim_set_current_win(source)
  if i > 1 then vim.api.nvim_buf_set_lines(0, 0, -1, false, { "print('LAUNCH_LATENCY_READY', flush=True)", "# change " .. i }) end
  local start = vim.uv.hrtime()
  require("util.run").file()
  local handler = (vim.uv.hrtime() - start) / 1e6
  assert(handler < 400, "Run handler blocked: " .. handler .. "ms")
  local task = require("ui.output").selected
  assert(task and vim.wait(15000, function()
    return task:is_complete() and table.concat(vim.api.nvim_buf_get_lines(task:get_bufnr(), 0, -1, false), ""):find("LAUNCH_LATENCY_READY", 1, true)
  end, 5))
  timings[#timings + 1] = { modified = i > 1, handler_ms = math.floor(handler), output_ms = math.floor((vim.uv.hrtime() - start) / 1e6) }
  require("ui.tools").hide()
end
print(vim.json.encode(timings))
