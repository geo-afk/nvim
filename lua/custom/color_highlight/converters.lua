local M = {}

function M.short_hex_to_hex(short_hex)
  local hex = short_hex:gsub('#', '')
  if #hex == 3 then
    -- #RGB -> #RRGGBB
    return '#' .. hex:sub(1, 1):rep(2) .. hex:sub(2, 2):rep(2) .. hex:sub(3, 3):rep(2)
  elseif #hex == 4 then
    -- #RGBA -> #RRGGBBAA
    return '#' .. hex:sub(1, 1):rep(2) .. hex:sub(2, 2):rep(2) .. hex:sub(3, 3):rep(2) .. hex:sub(4, 4):rep(2)
  end
  return short_hex
end

function M.rgb_to_hex(r, g, b)
  r = math.floor(tonumber(r) or 0)
  g = math.floor(tonumber(g) or 0)
  b = math.floor(tonumber(b) or 0)

  r = math.max(0, math.min(255, r))
  g = math.max(0, math.min(255, g))
  b = math.max(0, math.min(255, b))

  return string.format('#%02X%02X%02X', r, g, b)
end

function M.hsl_to_rgb(h, s, l)
  h = tonumber(h) or 0
  s = (tonumber(s) or 0) / 100
  l = (tonumber(l) or 0) / 100

  -- Normalize hue to 0-360
  h = h % 360
  if h < 0 then
    h = h + 360
  end
  h = h / 360

  local r, g, b

  if s == 0 then
    r, g, b = l, l, l
  else
    local function hue_to_rgb(p, q, t)
      if t < 0 then
        t = t + 1
      end
      if t > 1 then
        t = t - 1
      end
      if t < 1 / 6 then
        return p + (q - p) * 6 * t
      end
      if t < 1 / 2 then
        return q
      end
      if t < 2 / 3 then
        return p + (q - p) * (2 / 3 - t) * 6
      end
      return p
    end

    local q = l < 0.5 and l * (1 + s) or l + s - l * s
    local p = 2 * l - q

    r = hue_to_rgb(p, q, h + 1 / 3)
    g = hue_to_rgb(p, q, h)
    b = hue_to_rgb(p, q, h - 1 / 3)
  end

  return {
    math.floor(r * 255 + 0.5),
    math.floor(g * 255 + 0.5),
    math.floor(b * 255 + 0.5),
  }
end

return M
