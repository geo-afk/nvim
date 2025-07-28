local M = {}

M.kind_icons = {
  Copilot = "",
  Text = "󰉿",
  Method = "󰊕",
  Function = "󰊕",
  Constructor = "󰒓",

  Field = "󰜢",
  Variable = "󰆦",
  Property = "󰖷",

  Class = "󱡠",
  Interface = "󱡠",
  Struct = "󱡠",
  Module = "󰅩",

  Unit = "󰪚",
  Value = "󰦨",
  Enum = "󰦨",
  EnumMember = "󰦨",

  Keyword = "󰻾",
  Constant = "󰏿",

  Snippet = "󱄽",
  Color = "󰏘",
  File = "󰈔",
  Reference = "󰬲",
  Folder = "󰉋",
  Event = "󱐋",
  Operator = "󰪚",
  TypeParameter = "󰬛",
}

M.components = {
  -- customize the drawing of kind icons
  kind_icon = {
    text = function(ctx)
      -- default kind icon
      local icon = ctx.kind_icon
      -- if LSP source, check for color derived from documentation
      if ctx.item.source_name == "LSP" then
        local color_item = require("nvim-highlight-colors").format(ctx.item.documentation, { kind = ctx.kind })
        if color_item and color_item.abbr ~= "" then
          icon = color_item.abbr
        end
      end
      return icon .. ctx.icon_gap
    end,
    highlight = function(ctx)
      -- default highlight group
      local highlight = "BlinkCmpKind" .. ctx.kind
      -- if LSP source, check for color derived from documentation
      if ctx.item.source_name == "LSP" then
        local color_item = require("nvim-highlight-colors").format(ctx.item.documentation, { kind = ctx.kind })
        if color_item and color_item.abbr_hl_group then
          highlight = color_item.abbr_hl_group
        end
      end
      return highlight
    end,
  },
}

return M
