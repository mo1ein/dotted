-- Discover bundled names without parsing palettes or loading the renderer.
local M = {}
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h") .. "/themes-data"
local entries, records

local function slug(name)
  return name:lower():gsub("[^a-z0-9]+", "-"):gsub("^-", ""):gsub("-$", "")
end

function M.entries()
  if entries then return entries end
  entries, records = {}, {}
  local enabled = require "config.theme_imports"
  if enabled.ghostty then
    local provider = { bundled = true, source = "ghostty", schemes = {} }
    local scan = assert(vim.uv.fs_scandir(root .. "/ghostty"), "Bundled Ghostty palettes are missing")
    local files = {}
    while true do
      local name, kind = vim.uv.fs_scandir_next(scan)
      if not name then break end
      if kind == "file" and name:sub(1, 1) ~= "." then files[#files + 1] = name end
    end
    table.sort(files)
    for _, file in ipairs(files) do
      local id = "ghostty-" .. slug(file)
      if records[id] then id = id .. "-" .. vim.fn.sha256(file):sub(1, 8) end
      assert(not records[id], "Duplicate bundled theme ID: " .. id)
      provider.schemes[#provider.schemes + 1] = id
      records[id] = { source = "ghostty", name = file, path = root .. "/ghostty/" .. file }
    end
    entries[#entries + 1] = provider
  end
  if enabled.zed then
    local provider = { bundled = true, source = "zed", schemes = {} }
    -- Names from the pinned Zed assets; full JSON is read only on selection.
    for family, variants in pairs {
      ayu = { "Ayu Dark", "Ayu Light", "Ayu Mirage" },
      gruvbox = { "Gruvbox Dark", "Gruvbox Dark Hard", "Gruvbox Dark Soft", "Gruvbox Light", "Gruvbox Light Hard", "Gruvbox Light Soft" },
      one = { "One Dark", "One Light" },
    } do
      for _, name in ipairs(variants) do
        local id = "zed-" .. slug(name)
        provider.schemes[#provider.schemes + 1] = id
        records[id] = { source = "zed", name = name, path = root .. "/zed/" .. family .. "/" .. family .. ".json" }
      end
    end
    table.sort(provider.schemes)
    entries[#entries + 1] = provider
  end
  if enabled.vscode then
    local provider = { bundled = true, source = "vscode", schemes = {} }
    for id, variant in pairs {
      ["vscode-dark-2026"] = { "2026-dark.json", "dark" },
      ["vscode-light-2026"] = { "2026-light.json", "light" },
      ["vscode-dark-modern"] = { "dark_modern.json", "dark" },
      ["vscode-light-modern"] = { "light_modern.json", "light" },
      ["vscode-dark-plus"] = { "dark_plus.json", "dark" },
      ["vscode-light-plus"] = { "light_plus.json", "light" },
      ["vscode-dark"] = { "dark_vs.json", "dark" },
      ["vscode-light"] = { "light_vs.json", "light" },
      ["vscode-high-contrast-dark"] = { "hc_black.json", "dark", true },
      ["vscode-high-contrast-light"] = { "hc_light.json", "light", true },
    } do
      provider.schemes[#provider.schemes + 1] = id
      records[id] = { source = "vscode", path = root .. "/vscode/" .. variant[1], name = id, appearance = variant[2], high_contrast = variant[3] }
    end
    table.sort(provider.schemes)
    entries[#entries + 1] = provider
  end
  return entries
end

function M.find(scheme)
  M.entries()
  return records[scheme]
end

return M
