-- Shared terminal design: existing statusline stays owned by config/statusline.lua.
return {
  dashboard = true,
  bufferline = true,
  breadcrumbs = true,
  tools = { enabled = true, height = 12 },
  panel = { width = 0.80, height = 0.85, border = "rounded" },
  replace = { width = 64, buffer_height = 4, project_height = 9 },
}
