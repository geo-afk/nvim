local M = {}

local source_icons = {
  lsp = '', -- LSP icon
  lazydev = '', -- lazydev / Lua
  path = '', -- Path completion
  buffer = '', -- Buffer words
  snippets = '', -- Snippets
  -- Add more if you enable other sources (e.g., copilot = '')
}

-- Helper for contrasting text color on color swatches
local function get_contrast_fg(hex)
  hex = hex:gsub('#', '')
  local r = tonumber(hex:sub(1, 2), 16) / 255
  local g = tonumber(hex:sub(3, 4), 16) / 255
  local b = tonumber(hex:sub(5, 6), 16) / 255
  local lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
  return lum > 0.5 and '#000000' or '#FFFFFF'
end

-- Modern, clean kind icons (codicons-inspired)
M.kind_icons = {
  Version = ' ',
  Unknown = '  ',
  Null = '󰟢',
  Namespace = '󰌗',
  Text = '󰉿',
  Calculator = ' ',
  Watch = '󰥔',
  Folder = '󰉋',
  Table = '',
  File = '󰈚',
  TypeParameter = '󰊄',
  Operator = '󰆕',
  Emoji = '󰞅 ',
  Copilot = '',
  Keyword = '󰌋',
  Snippet = '',
  Method = '󰊕',
  Function = '󰊕',
  Constructor = '󰒓',
  Array = ' ',
  Field = '󰜢',
  Property = '󰖷',
  Boolean = '󰨙 ',
  Class = '󱡠',
  Interface = '󱡠',
  Struct = '󱡠',
  Module = '󰅩',
  Control = ' ',
  Collapsed = ' ',
  Unit = ' ',
  Value = '󰦨',
  Key = ' ',
  Constant = '󰏿',
  Enum = ' ',
  EnumMember = ' ',
  Color = '󰏘',
  Reference = '󰬲',
  Event = '󱐋',

  Number = '󰎠 ',
  Object = ' ',
  Package = ' ',
  String = ' ',
  Supermaven = ' ',
  TabNine = '󰏚 ',
  Variable = '󰀫 ',
}

-- Safely load nvim-highlight-colors if available
local c_highlight = (function()
  local ok, mod = pcall(require, 'nvim-highlight-colors')
  return ok and mod or nil
end)()

M.components = {
  kind_icon = {
    text = function(ctx)
      local icon = ctx.kind_icon .. (ctx.icon_gap or ' ')

      -- Safely use nvim-highlight-colors if available
      if ctx.item.source_name == 'LSP' and c_highlight then
        local ok, color_item = pcall(c_highlight.format, ctx.item.documentation, { kind = ctx.kind })
        if ok and color_item and color_item.abbr ~= '' then
          icon = color_item.abbr
        end
      end

      -- Override with devicons for paths - safely loaded
      if ctx.source_name == 'Path' then
        local ok, devicons = pcall(require, 'nvim-web-devicons')
        if ok then
          local dev_icon, _ = devicons.get_icon(ctx.label)
          if dev_icon then
            icon = dev_icon .. ' '
          end
        end
      end

      -- Color swatch preview for Color kind (Tailwind, CSS, etc.)
      if ctx.kind == 'Color' then
        local hex = nil

        -- Try to get documentation from LSP item
        local doc = ctx.item.documentation
        if type(doc) == 'string' then
          hex = doc:match '^#(%x%x%x%x%x%x)$'
        elseif type(doc) == 'table' and doc.kind == 'markdown' and doc.value then
          hex = doc.value:match '^#(%x%x%x%x%x%x)$'
        end

        -- Fallback to label description (often contains the color value)
        if not hex and ctx.label_description then
          hex = ctx.label_description:match '#(%x%x%x%x%x%x)'
        end

        if hex then
          hex = '#' .. hex:upper()
          local hl_name = 'BlinkCmpColor' .. hex:sub(2)
          if vim.fn.hlexists(hl_name) == 0 then
            pcall(vim.api.nvim_set_hl, 0, hl_name, { fg = get_contrast_fg(hex), bg = hex })
          end
          ctx.highlight = hl_name
          icon = '󱓻'
        end
      end
      return ' ' .. icon .. ' '
    end,
    highlight = function(ctx)
      local highlight = 'BlinkCmpKind' .. ctx.kind

      -- Fallback to nvim-highlight-colors if available - safely accessed
      if ctx.item.source_name == 'LSP' and c_highlight then
        local ok, color_item = pcall(c_highlight.format, ctx.item.documentation, { kind = ctx.kind })
        if ok and color_item and color_item.abbr_hl_group then
          highlight = color_item.abbr_hl_group
        end
      end

      return highlight
    end,
  },

  label = {
    width = { fill = true, max = 60 },
    text = function(ctx)
      -- Safely use colorful-menu if available
      local ok, colorful = pcall(require, 'colorful-menu')
      if ok then
        local ok2, highlights_info = pcall(colorful.blink_highlights, ctx)
        if ok2 and highlights_info and highlights_info.label then
          return highlights_info.label
        end
      end
      return ctx.label
    end,
    highlight = function(ctx)
      local highlights = {}

      -- Safely use colorful-menu if available
      local ok, colorful = pcall(require, 'colorful-menu')
      if ok then
        local ok2, highlights_info = pcall(colorful.blink_highlights, ctx)
        if ok2 and highlights_info and highlights_info.highlights then
          highlights = highlights_info.highlights
        end
      end

      for _, idx in ipairs(ctx.label_matched_indices or {}) do
        table.insert(highlights, { idx, idx + 1, group = 'BlinkCmpLabelMatch' })
      end

      -- Deprecated items
      if ctx.deprecated then
        table.insert(highlights, { 1, -1, group = 'BlinkCmpLabelDeprecated' })
      end

      return highlights
    end,
  },
}

return M
