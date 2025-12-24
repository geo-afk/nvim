local M = {}

function M.get_rgb_values(color)
  local values = {}
  -- Match rgb(r, g, b) or rgba(r, g, b, a)
  for val in color:gmatch '%d+%.?%d*' do
    table.insert(values, tonumber(val))
  end
  return values
end

function M.get_hsl_values(color)
  local values = {}
  -- Match hsl(h, s%, l%) or hsla(h, s%, l%, a)
  local h = color:match '(%d+%.?%d*)%s*,'
  local s = color:match ',(%d+%.?%d*)%%'
  local l = color:match '%%%s*,(%d+%.?%d*)%%'

  if not l then
    -- Try without commas: hsl(h s% l%)
    h, s, l = color:match '(%d+%.?%d*)%s+(%d+%.?%d*)%%%s+(%d+%.?%d*)%%'
  end

  if h and s and l then
    values[1] = tonumber(h)
    values[2] = tonumber(s)
    values[3] = tonumber(l)
  end

  return values
end

function M.get_hsl_without_func_values(color)
  local values = {}
  -- Match "h s% l%" format
  local h, s, l = color:match '(%d+%.?%d*)%s+(%d+%.?%d*)%%%s+(%d+%.?%d*)%%'

  if h and s and l then
    values[1] = tonumber(h)
    values[2] = tonumber(s)
    values[3] = tonumber(l)
  end

  return values
end

function M.get_css_named_color_pattern()
  return '^[a-z]+$'
end

function M.get_tailwind_named_color_pattern()
  return '^[a-z]+-[0-9]+$'
end

function M.get_css_named_color_value(color)
  local css_colors = {
    aliceblue = '#F0F8FF',
    antiquewhite = '#FAEBD7',
    aqua = '#00FFFF',
    aquamarine = '#7FFFD4',
    azure = '#F0FFFF',
    beige = '#F5F5DC',
    bisque = '#FFE4C4',
    black = '#000000',
    blanchedalmond = '#FFEBCD',
    blue = '#0000FF',
    blueviolet = '#8A2BE2',
    brown = '#A52A2A',
    burlywood = '#DEB887',
    cadetblue = '#5F9EA0',
    chartreuse = '#7FFF00',
    chocolate = '#D2691E',
    coral = '#FF7F50',
    cornflowerblue = '#6495ED',
    cornsilk = '#FFF8DC',
    crimson = '#DC143C',
    cyan = '#00FFFF',
    darkblue = '#00008B',
    darkcyan = '#008B8B',
    darkgoldenrod = '#B8860B',
    darkgray = '#A9A9A9',
    darkgreen = '#006400',
    darkgrey = '#A9A9A9',
    darkkhaki = '#BDB76B',
    darkmagenta = '#8B008B',
    darkolivegreen = '#556B2F',
    darkorange = '#FF8C00',
    darkorchid = '#9932CC',
    darkred = '#8B0000',
    darksalmon = '#E9967A',
    darkseagreen = '#8FBC8F',
    darkslateblue = '#483D8B',
    darkslategray = '#2F4F4F',
    darkslategrey = '#2F4F4F',
    darkturquoise = '#00CED1',
    darkviolet = '#9400D3',
    deeppink = '#FF1493',
    deepskyblue = '#00BFFF',
    dimgray = '#696969',
    dimgrey = '#696969',
    dodgerblue = '#1E90FF',
    firebrick = '#B22222',
    floralwhite = '#FFFAF0',
    forestgreen = '#228B22',
    fuchsia = '#FF00FF',
    gainsboro = '#DCDCDC',
    ghostwhite = '#F8F8FF',
    gold = '#FFD700',
    goldenrod = '#DAA520',
    gray = '#808080',
    green = '#008000',
    greenyellow = '#ADFF2F',
    grey = '#808080',
    honeydew = '#F0FFF0',
    hotpink = '#FF69B4',
    indianred = '#CD5C5C',
    indigo = '#4B0082',
    ivory = '#FFFFF0',
    khaki = '#F0E68C',
    lavender = '#E6E6FA',
    lavenderblush = '#FFF0F5',
    lawngreen = '#7CFC00',
    lemonchiffon = '#FFFACD',
    lightblue = '#ADD8E6',
    lightcoral = '#F08080',
    lightcyan = '#E0FFFF',
    lightgoldenrodyellow = '#FAFAD2',
    lightgray = '#D3D3D3',
    lightgreen = '#90EE90',
    lightgrey = '#D3D3D3',
    lightpink = '#FFB6C1',
    lightsalmon = '#FFA07A',
    lightseagreen = '#20B2AA',
    lightskyblue = '#87CEFA',
    lightslategray = '#778899',
    lightslategrey = '#778899',
    lightsteelblue = '#B0C4DE',
    lightyellow = '#FFFFE0',
    lime = '#00FF00',
    limegreen = '#32CD32',
    linen = '#FAF0E6',
    magenta = '#FF00FF',
    maroon = '#800000',
    mediumaquamarine = '#66CDAA',
    mediumblue = '#0000CD',
    mediumorchid = '#BA55D3',
    mediumpurple = '#9370DB',
    mediumseagreen = '#3CB371',
    mediumslateblue = '#7B68EE',
    mediumspringgreen = '#00FA9A',
    mediumturquoise = '#48D1CC',
    mediumvioletred = '#C71585',
    midnightblue = '#191970',
    mintcream = '#F5FFFA',
    mistyrose = '#FFE4E1',
    moccasin = '#FFE4B5',
    navajowhite = '#FFDEAD',
    navy = '#000080',
    oldlace = '#FDF5E6',
    olive = '#808000',
    olivedrab = '#6B8E23',
    orange = '#FFA500',
    orangered = '#FF4500',
    orchid = '#DA70D6',
    palegoldenrod = '#EEE8AA',
    palegreen = '#98FB98',
    paleturquoise = '#AFEEEE',
    palevioletred = '#DB7093',
    papayawhip = '#FFEFD5',
    peachpuff = '#FFDAB9',
    peru = '#CD853F',
    pink = '#FFC0CB',
    plum = '#DDA0DD',
    powderblue = '#B0E0E6',
    purple = '#800080',
    red = '#FF0000',
    rosybrown = '#BC8F8F',
    royalblue = '#4169E1',
    saddlebrown = '#8B4513',
    salmon = '#FA8072',
    sandybrown = '#F4A460',
    seagreen = '#2E8B57',
    seashell = '#FFF5EE',
    sienna = '#A0522D',
    silver = '#C0C0C0',
    skyblue = '#87CEEB',
    slateblue = '#6A5ACD',
    slategray = '#708090',
    slategrey = '#708090',
    snow = '#FFFAFA',
    springgreen = '#00FF7F',
    steelblue = '#4682B4',
    tan = '#D2B48C',
    teal = '#008080',
    thistle = '#D8BFD8',
    tomato = '#FF6347',
    turquoise = '#40E0D0',
    violet = '#EE82EE',
    wheat = '#F5DEB3',
    white = '#FFFFFF',
    whitesmoke = '#F5F5F5',
    yellow = '#FFFF00',
    yellowgreen = '#9ACD32',
  }

  return css_colors[color:lower()]
end

function M.get_ansi_named_color_value(color)
  local ansi_colors = {
    black = '#000000',
    red = '#FF0000',
    green = '#00FF00',
    yellow = '#FFFF00',
    blue = '#0000FF',
    magenta = '#FF00FF',
    cyan = '#00FFFF',
    white = '#FFFFFF',
    brightblack = '#808080',
    brightred = '#FF8080',
    brightgreen = '#80FF80',
    brightyellow = '#FFFF80',
    brightblue = '#8080FF',
    brightmagenta = '#FF80FF',
    brightcyan = '#80FFFF',
    brightwhite = '#FFFFFF',
  }

  return ansi_colors[color:lower()]
end

function M.get_tailwind_named_color_value(color)
  -- Simplified Tailwind color palette
  -- In a real implementation, this would be much more extensive
  local tailwind_colors = {
    ['slate-50'] = '#f8fafc',
    ['slate-100'] = '#f1f5f9',
    ['slate-200'] = '#e2e8f0',
    ['slate-300'] = '#cbd5e1',
    ['slate-400'] = '#94a3b8',
    ['slate-500'] = '#64748b',
    ['slate-600'] = '#475569',
    ['slate-700'] = '#334155',
    ['slate-800'] = '#1e293b',
    ['slate-900'] = '#0f172a',
    ['red-500'] = '#ef4444',
    ['blue-500'] = '#3b82f6',
    ['green-500'] = '#22c55e',
    ['yellow-500'] = '#eab308',
    ['purple-500'] = '#a855f7',
    ['pink-500'] = '#ec4899',
    -- Add more as needed
  }

  return tailwind_colors[color:lower()]
end

function M.get_css_var_color(color, row_offset)
  -- This would need to parse CSS and find the variable definition
  -- Simplified implementation - returns nil as it requires file parsing
  return nil
end

function M.get_custom_color(color, custom_colors)
  for pattern, value in pairs(custom_colors) do
    if color:match(pattern) then
      if type(value) == 'function' then
        return value(color)
      else
        return value
      end
    end
  end
  return nil
end

return M
