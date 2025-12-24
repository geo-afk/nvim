local M = {}

function M.is_short_hex_color(color)
  return color:match '^#%x%x%x$' ~= nil
end

function M.is_alpha_layer_short_hex(color)
  return color:match '^#%x%x%x%x$' ~= nil
end

function M.is_alpha_layer_hex(color)
  return color:match '^#%x%x%x%x%x%x%x%x$' ~= nil
end

function M.is_hex_color(color)
  return color:match '^#%x%x%x%x%x%x$' ~= nil
end

function M.is_rgb_color(color)
  return color:match '^rgba?%s*%(' ~= nil
end

function M.is_hsl_color(color)
  return color:match '^hsla?%s*%(' ~= nil
end

function M.is_hsl_without_func_color(color)
  -- Matches HSL without function syntax, e.g., "180 50% 50%"
  return color:match '^%d+%s+%d+%%%s+%d+%%' ~= nil
end

function M.is_named_color(patterns_table, color)
  for _, pattern in ipairs(patterns_table) do
    if color:match(pattern) then
      return true
    end
  end
  return false
end

function M.is_ansi_color(color)
  local ansi_colors = {
    'black',
    'red',
    'green',
    'yellow',
    'blue',
    'magenta',
    'cyan',
    'white',
    'brightblack',
    'brightred',
    'brightgreen',
    'brightyellow',
    'brightblue',
    'brightmagenta',
    'brightcyan',
    'brightwhite',
  }

  for _, ansi in ipairs(ansi_colors) do
    if color:lower() == ansi then
      return true
    end
  end
  return false
end

function M.is_var_color(color)
  return color:match '^var%s*%(' ~= nil or color:match '^%-%-' ~= nil
end

function M.is_custom_color(color, custom_colors)
  if not custom_colors then
    return false
  end
  for pattern, _ in pairs(custom_colors) do
    if color:match(pattern) then
      return true
    end
  end
  return false
end

return M
