local M = {}

-- Fallback default OneDark-like palette
local function default_onedark_palette()
  return {
    bg0 = '#282c34',
    bg1 = '#31353f',
    bg2 = '#3e4452',
    bg3 = '#3e4452',
    fg = '#abb2bf',
    fg_alt = '#5c6370',
    red = '#e06c75',
    green = '#98c379',
    yellow = '#e5c07b',
    blue = '#61afef',
    purple = '#c678dd',
    cyan = '#56b6c2',
    orange = '#d19a66',
    git_add = '#98c379',
    git_change = '#e5c07b',
    git_delete = '#e06c75',
    gray = '#5c6370',
  }
end

-- Try to get OneDarkPro colors via helpers
local function try_onedarkpro_colors()
  local ok, helpers = pcall(require, 'onedarkpro.helpers')
  if ok and type(helpers.get_preloaded_colors) == 'function' then
    local colors = helpers.get_preloaded_colors()
    if colors and next(colors) then
      return colors
    end
  end
  return nil
end

-- Public: return best available palette
function M.get_palette()
  local colors = try_onedarkpro_colors()
  if colors then
    return colors
  else
    return default_onedark_palette()
  end
end

-- Public: build lualine theme
function M.get_lualine_theme()
  local colors = M.get_palette()
  return {
    normal = { a = { fg = colors.bg0, bg = colors.blue, gui = 'bold' }, b = { fg = colors.fg, bg = colors.bg2 }, c = { fg = colors.fg, bg = colors.bg0 } },
    insert = { a = { fg = colors.bg0, bg = colors.green, gui = 'bold' }, b = { fg = colors.fg, bg = colors.bg2 }, c = { fg = colors.fg, bg = colors.bg0 } },
    visual = { a = { fg = colors.bg0, bg = colors.purple, gui = 'bold' }, b = { fg = colors.fg, bg = colors.bg2 }, c = { fg = colors.fg, bg = colors.bg0 } },
    replace = { a = { fg = colors.bg0, bg = colors.red, gui = 'bold' }, b = { fg = colors.fg, bg = colors.bg2 }, c = { fg = colors.fg, bg = colors.bg0 } },
    command = { a = { fg = colors.bg0, bg = colors.yellow, gui = 'bold' }, b = { fg = colors.fg, bg = colors.bg2 }, c = { fg = colors.fg, bg = colors.bg0 } },
    terminal = { a = { fg = colors.bg0, bg = colors.cyan, gui = 'bold' }, b = { fg = colors.fg, bg = colors.bg2 }, c = { fg = colors.fg, bg = colors.bg0 } },
    inactive = { a = { fg = colors.gray, bg = colors.bg1 }, b = { fg = colors.gray, bg = colors.bg1 }, c = { fg = colors.gray, bg = colors.bg0 } },
  }
end

return M
