-- Python selection precedence and isolated-adapter discovery without DAP/plugins.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(root)
local python, config = require "configs.dap_python", require("config.debug").python
local directory = vim.fn.tempname()
vim.fn.mkdir(directory .. "/project/nested", "p")
directory = assert(vim.uv.fs_realpath(directory))
local function environment(name)
  local path = directory .. "/" .. name .. "/bin/python"
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
  vim.fn.writefile({ "#!/bin/sh", "exit 0" }, path)
  assert(vim.uv.fs_chmod(path, 448))
  return path
end
local project = environment "project/.venv"
local activated = environment "activated"
local conda = environment "conda"
local explicit = environment "explicit"
vim.api.nvim_buf_set_name(0, directory .. "/project/nested/main.py")
vim.env.VIRTUAL_ENV, vim.env.CONDA_PREFIX = nil, nil
assert(python.interpreter() == project)
vim.env.CONDA_PREFIX = directory .. "/conda"
assert(python.interpreter() == conda)
vim.env.VIRTUAL_ENV = directory .. "/activated"
assert(python.interpreter() == activated)
config.interpreter = explicit
assert(python.interpreter() == explicit)
assert(select("#", python.interpreter()) == 1, "Interpreter resolver leaked an error message into launch arguments")
config.interpreter = directory .. "/missing"
assert(not pcall(python.interpreter), "An invalid explicit interpreter silently fell back")
config.interpreter = nil
config.adapter = explicit
assert(python.adapter_python() == explicit)
config.adapter = directory .. "/missing"
assert(python.adapter_python() == nil)
config.adapter = nil
assert(vim.v.errmsg == "", vim.v.errmsg)
print "Python interpreter: nearest project venv, activated env/Conda, explicit overrides, and invalid-path checks passed"
