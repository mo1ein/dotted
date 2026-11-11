-- Debugger executables only; language-specific launch settings live in configs/dap*.
return {
  delve = nil,
  timeout = 30,
  python = {
    adapter = nil, -- default: stdpath("data")/debugpy/bin/python; Mason is a fallback
    interpreter = nil, -- activated env, nearest .venv/venv, then python3/python on PATH
  },
}
