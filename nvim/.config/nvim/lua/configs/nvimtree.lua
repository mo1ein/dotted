-- File explorer options; highlights come directly from the colorscheme.

return {
  on_attach = function(buf) require("ui.explorer").attach(buf) end,
  sort = { sorter = function(nodes) require("ui.explorer").sorter(nodes) end },
  live_filter = { prefix = " Find: ", always_show_folders = false },
  filters = { dotfiles = false },
  disable_netrw = true,
  -- options.lua disables netrw before its FileExplorer group can be created.
  hijack_netrw = false,
  hijack_cursor = true,
  sync_root_with_cwd = true,
  update_focused_file = {
    -- ui.explorer_selection owns following, including the toolbar toggle.
    enable = false,
    update_root = false,
  },
  view = {
    width = 30,
    cursorlineopt = "line",
    preserve_window_proportions = true,
  },
  renderer = {
    root_folder_label = false,
    highlight_git = true,
    indent_markers = { enable = true },
    icons = {
      glyphs = {
        default = "󰈚",
        folder = {
          default = "",
          empty = "",
          empty_open = "",
          open = "",
          symlink = "",
        },
        git = { unmerged = "" },
      },
    },
  },
}
