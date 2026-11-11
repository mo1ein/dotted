-- Small color/contrast helpers for owned UI elements; no palette dependencies.
local M = {}

local function channels(value)
  return math.floor(value / 65536) % 256, math.floor(value / 256) % 256, value % 256
end

function M.mix(front, back, amount)
  local r, g, b = channels(front)
  local br, bg, bb = channels(back)
  local function blend(a, z) return math.floor(a * amount + z * (1 - amount) + 0.5) end
  return blend(r, br) * 65536 + blend(g, bg) * 256 + blend(b, bb)
end

local function luminance(value)
  local r, g, b = channels(value)
  local function linear(c)
    c = c / 255
    return c <= 0.04045 and c / 12.92 or ((c + 0.055) / 1.055) ^ 2.4
  end
  return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
end

function M.contrast(a, b)
  local first, second = luminance(a), luminance(b)
  return (math.max(first, second) + 0.05) / (math.min(first, second) + 0.05)
end

function M.text_on(background)
  return M.contrast(0xffffff, background) > M.contrast(0x000000, background) and 0xffffff or 0x000000
end

function M.readable(foreground, background, minimum)
  minimum = minimum or 4.5
  if M.contrast(foreground, background) >= minimum then return foreground end
  local endpoint = M.text_on(background)
  for i = 1, 16 do
    local adjusted = M.mix(endpoint, foreground, i / 16)
    if M.contrast(adjusted, background) >= minimum then return adjusted end
  end
  return endpoint
end

function M.get(group)
  local attrs = vim.api.nvim_get_hl(0, { name = group, link = false, create = false })
  if attrs.reverse or attrs.standout then
    attrs.fg, attrs.bg = attrs.bg, attrs.fg
    attrs.reverse, attrs.standout = nil, nil
  end
  return attrs
end

return M
