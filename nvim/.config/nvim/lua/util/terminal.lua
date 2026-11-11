-- Owned terminal splits/floats with persistent toggle buffers; no plugin needed.
local M = {}
local terminals = {}

local function show(buf, opts)
  if opts.pos == "float" then
    local width = math.max(1, math.floor(vim.o.columns * 0.8))
    local height = math.max(1, math.floor((vim.o.lines - 2) * 0.8))
    vim.api.nvim_open_win(buf, true, {
      relative = "editor", style = "minimal", border = "rounded",
      width = width, height = height,
      col = math.floor((vim.o.columns - width) / 2),
      row = math.floor((vim.o.lines - height) / 2),
    })
  else
    vim.cmd(opts.pos == "vsp" and "botright vnew" or "botright new")
    local empty = vim.api.nvim_get_current_buf()
    vim.api.nvim_win_set_buf(0, buf)
    vim.api.nvim_buf_delete(empty, { force = true })
  end
  vim.bo[buf].bufhidden = "hide"
  vim.cmd "startinsert"
end

function M.new(opts)
  opts = opts or {}
  local buf = vim.api.nvim_create_buf(false, true)
  vim.b[buf].dotted_terminal = true
  show(buf, opts)
  vim.fn.jobstart(vim.o.shell, { term = true })
  return buf
end

-- A terminal can be mounted in the bottom drawer without moving other windows.
function M.acquire(id, fresh)
  local buf = not fresh and terminals[id] or nil
  if buf and vim.api.nvim_buf_is_valid(buf) and vim.fn.jobwait({ vim.b[buf].terminal_job_id }, 0)[1] == -1 then return buf end
  buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "hide"
  vim.b[buf].dotted_terminal = true
  vim.api.nvim_buf_call(buf, function() vim.fn.jobstart(vim.o.shell, { term = true }) end)
  terminals[id] = buf
  return buf
end

function M.list()
  local result = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.b[buf].dotted_terminal and vim.bo[buf].buftype == "terminal" then result[#result + 1] = buf end
  end
  return result
end

function M.toggle(opts)
  opts = opts or {}
  local id = opts.id or opts.pos or "float"
  local buf = terminals[id]
  if buf and vim.api.nvim_buf_is_valid(buf) then
    local job = vim.b[buf].terminal_job_id
    if job and vim.fn.jobwait({ job }, 0)[1] == -1 then
      for _, win in ipairs(vim.fn.win_findbuf(buf)) do
        if #vim.api.nvim_list_wins() == 1 then
          vim.api.nvim_win_set_buf(win, vim.api.nvim_create_buf(true, false))
        else
          vim.api.nvim_win_close(win, true)
        end
        return
      end
      show(buf, opts)
      return
    end
  end
  terminals[id] = M.new(opts)
end

return M
