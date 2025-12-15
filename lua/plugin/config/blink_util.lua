local M = {}

M.kind_icons = {
  Version = ' ',
  Unknown = '  ',
  Calculator = ' ',
  Emoji = '󰞅 ',
  Copilot = '',
  Text = ' ',
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
  Keyword = '󰻾',
  Constant = '󰏿',
  Enum = ' ',
  EnumMember = ' ',
  Snippet = '󱄽',
  Color = '󰏘',
  File = '󰈔',
  Reference = '󰬲',
  Folder = '󰉋',
  Event = '󱐋',
  Operator = '󰪚',
  TypeParameter = '󰬛',

  Null = ' ',
  Number = '󰎠 ',
  Object = ' ',
  Package = ' ',
  String = ' ',
  Supermaven = ' ',
  TabNine = '󰏚 ',
  Variable = '󰀫 ',
}

M.components = {
  -- kind_icon = {
  --   text = function(ctx)
  --     -- default kind icon
  --     local icon = ctx.kind_icon
  --     -- if LSP source, check for color derived from documentation
  --     if ctx.item.source_name == 'LSP' then
  --       local color_item = require('nvim-highlight-colors').format(ctx.item.documentation, { kind = ctx.kind })
  --       if color_item and color_item.abbr ~= '' then
  --         icon = color_item.abbr
  --       end
  --     elseif vim.tbl_contains({ 'Path' }, ctx.source_name) then
  --       local dev_icon, _ = require('nvim-web-devicons').get_icon(ctx.label)
  --       if dev_icon then
  --         icon = dev_icon
  --       end
  --     end
  --     return icon .. ctx.icon_gap
  --   end,
  --   highlight = function(ctx)
  --     -- default highlight group
  --     local highlight = 'BlinkCmpKind' .. ctx.kind
  --     -- if LSP source, check for color derived from documentation
  --     if ctx.item.source_name == 'LSP' then
  --       local color_item = require('nvim-highlight-colors').format(ctx.item.documentation, { kind = ctx.kind })
  --       if color_item and color_item.abbr_hl_group then
  --         highlight = color_item.abbr_hl_group
  --       end
  --     end
  --     return highlight
  --   end,
  -- },
  label = {
    width = { fill = true, max = 60 },
    text = function(ctx)
      local highlights_info = require('colorful-menu').blink_highlights(ctx)
      if highlights_info ~= nil then
        -- Or you want to add more item to label
        return highlights_info.label
      else
        return ctx.label
      end
    end,
    highlight = function(ctx)
      local highlights = {}
      local highlights_info = require('colorful-menu').blink_highlights(ctx)
      if highlights_info ~= nil then
        highlights = highlights_info.highlights
      end
      for _, idx in ipairs(ctx.label_matched_indices) do
        table.insert(highlights, { idx, idx + 1, group = 'BlinkCmpLabelMatch' })
      end
      -- Do something else
      return highlights
    end,
  },
}

return M
