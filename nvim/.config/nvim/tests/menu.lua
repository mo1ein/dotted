-- Menu-only cursor/mouse ownership and cleanup, including external dismissals.
assert(vim.env.NVIM_TEST_ISOLATED == "1")
local menus = require "ui.menu"
local source = vim.api.nvim_get_current_win()
local cursor, mousemove = vim.o.guicursor, vim.o.mousemoveevent
local closed, chosen = 0, 0
local function open()
  return menus.open {
    source = source,
    items = {
      { label = "First", action = function() chosen = chosen + 1 end },
      { label = "Second", action = function() chosen = chosen + 1 end },
    },
    on_close = function() closed = closed + 1 end,
  }
end
local function restored()
  assert(vim.o.guicursor == cursor, "Menu leaked its hidden cursor into the editor")
  assert(vim.o.mousemoveevent == mousemove, "Menu leaked its mouse-motion setting")
end
local menu = open()
assert(vim.o.guicursor:find("DottedMenuCursor", 1, true) and vim.o.mousemoveevent)
assert(vim.api.nvim_get_hl(0, { name = "DottedMenuCursor", link = false }).blend == 100)
assert(vim.wo[menu.win].cursorlineopt == "line", "Menu selection is not a full row")
vim.cmd.colorscheme "habamax"
assert(vim.api.nvim_get_hl(0, { name = "DottedMenuCursor", link = false }).blend == 100, "Theme change restored the menu caret")
menu:close()
menu:close()
assert(closed == 1 and chosen == 0)
restored()
menu = open()
vim.api.nvim_win_close(menu.win, true)
assert(menu.closed and closed == 2)
restored()
menu = open()
local next_menu = open()
assert(menu.closed and not vim.api.nvim_win_is_valid(menu.win) and closed == 3, "Replacing a menu left an old popup open")
next_menu:close()
restored()
menu = open()
vim.api.nvim_set_current_win(source)
assert(vim.wait(1000, function() return menu.closed end, 10), "Leaving the menu didn't dismiss it")
assert(vim.api.nvim_get_current_win() == source)
restored()
menu = open()
vim.api.nvim_buf_delete(menu.buf, { force = true })
assert(menu.closed)
restored()
-- A setting changed explicitly while a menu is open must not be overwritten.
menu = open()
vim.o.guicursor, vim.o.mousemoveevent = "a:hor20", false
menu:close()
assert(vim.o.guicursor == "a:hor20" and not vim.o.mousemoveevent)
vim.o.guicursor, vim.o.mousemoveevent = cursor, mousemove
assert(vim.v.errmsg == "", vim.v.errmsg)
print "Menu: invisible caret, full-row selection, theme changes, singleton replacement, external close/leave/wipe and cursor/mouse preference restoration passed"
