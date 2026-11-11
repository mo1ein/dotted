-- Owned dap-ui lifecycle. Upstream considers a layout open when *any* pane
-- survives, but resize() assumes every tracked window still exists.
local M = {}
local configured = false

local function plugin()
  require "dap" -- Load the shared config even when the UI key is used first.
  return require "dapui"
end

local function repair_layouts()
  -- Narrow compatibility seam with dap-ui's window bookkeeping; do not rerun
  -- setup(), replace element buffers, or suppress unexpected plugin errors.
  for _, layout in ipairs(require("dapui.windows").layouts) do
    local owned, buffers, incomplete = {}, {}, false
    for index in ipairs(layout.win_states) do
      local win = layout.opened_wins[index]
      local buffer = win and layout.win_bufs[win]
      if win and vim.api.nvim_win_is_valid(win) and buffer and vim.api.nvim_win_get_buf(win) == buffer() then
        owned[index], buffers[win] = win, buffer
      else
        incomplete = true
      end
    end
    if incomplete then
      -- Keep the last complete sizes: sampling a partial layout distorts them.
      -- Detach repurposed user windows and callbacks before closing UI panes.
      layout.opened_wins, layout.win_bufs = owned, {}
      layout:close()
    else
      layout.win_bufs = buffers -- Drop callbacks left behind by earlier closes.
    end
  end
end

function M.open()
  local dapui = plugin()
  repair_layouts()
  dapui.open()
  local tools = package.loaded["ui.tools"]
  if tools then tools.refresh_debug() end
end

function M.close()
  local dapui = plugin()
  repair_layouts()
  dapui.close()
  for _, layout in ipairs(require("dapui.windows").layouts) do layout.win_bufs = {} end
end

function M.toggle()
  plugin()
  -- Toggle the debugger as a whole, not each surviving layout independently.
  for _, layout in ipairs(require("dapui.windows").layouts) do
    if layout:is_open() then return M.close() end
  end
  M.open()
end

function M.setup(dap)
  if not configured then
    require("dapui").setup { floating = { border = "rounded" } }
    configured = true
  end
  -- Replace the original keys too, so reloading removes cached old listeners.
  dap.listeners.after.event_initialized.dapui_config = M.open
  dap.listeners.before.event_terminated.dapui_config = M.close
  dap.listeners.before.event_exited.dapui_config = M.close
end

return M
