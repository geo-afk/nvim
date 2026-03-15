-- ─────────────────────────────────────────────────────────────────────────────
-- blink.cmp — single-file spec (config.lua merged in to avoid lazy.nvim
-- treating it as an invalid plugin spec when it scans the directory).
-- All optional dependencies (nvim-highlight-colors, nvim-web-devicons,
-- colorful-menu) are guarded with pcall so missing plugins never hard-error.
-- ─────────────────────────────────────────────────────────────────────────────

-- ── Helpers ──────────────────────────────────────────────────────────────────

--- Return a contrasting foreground colour (#000000 or #FFFFFF) for a hex bg.
---@param hex string  e.g. "#A3B4C5"
---@return string
local function get_contrast_fg(hex)
  hex = hex:gsub('#', '')
  if #hex ~= 6 then return '#FFFFFF' end
  local r = (tonumber(hex:sub(1, 2), 16) or 0) / 255
  local g = (tonumber(hex:sub(3, 4), 16) or 0) / 255
  local b = (tonumber(hex:sub(5, 6), 16) or 0) / 255
  local lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
  return lum > 0.5 and '#000000' or '#FFFFFF'
end

--- Safely require a module; returns the module or nil (never throws).
---@param mod string
---@return table|nil
local function try_require(mod)
  local ok, result = pcall(require, mod)
  return ok and result or nil
end

-- ── Optional dependency handles (resolved once at load time) ─────────────────

local c_highlight = try_require('nvim-highlight-colors')

-- ── Kind icons ────────────────────────────────────────────────────────────────

local kind_icons = {
  Version        = ' ',
  Unknown        = '  ',
  Null           = '󰟢',
  Namespace      = '󰌗',
  Text           = '󰉿',
  Calculator     = ' ',
  Watch          = '󰥔',
  Folder         = '󰉋',
  Table          = '',
  File           = '󰈚',
  TypeParameter  = '󰊄',
  Operator       = '󰆕',
  Emoji          = '󰞅 ',
  Copilot        = '',
  Keyword        = '󰌋',
  Snippet        = '',
  Method         = '󰊕',
  Function       = '󰊕',
  Constructor    = '󰒓',
  Array          = ' ',
  Field          = '󰜢',
  Property       = '󰖷',
  Boolean        = '󰨙 ',
  Class          = '󱡠',
  Interface      = '󱡠',
  Struct         = '󱡠',
  Module         = '󰅩',
  Control        = ' ',
  Collapsed      = ' ',
  Unit           = ' ',
  Value          = '󰦨',
  Key            = ' ',
  Constant       = '󰏿',
  Enum           = ' ',
  EnumMember     = ' ',
  Color          = '󰏘',
  Reference      = '󰬲',
  Event          = '󱐋',
  Number         = '󰎠 ',
  Object         = ' ',
  Package        = ' ',
  String         = ' ',
  Supermaven     = ' ',
  TabNine        = '󰏚 ',
  Variable       = '󰀫 ',
}

-- ── Draw components ───────────────────────────────────────────────────────────

local components = {
  -- ── kind_icon ──────────────────────────────────────────────────────────────
  kind_icon = {
    text = function(ctx)
      local icon = (ctx.kind_icon or '') .. (ctx.icon_gap or ' ')

      -- nvim-highlight-colors: colour swatch abbreviation for LSP items
      if ctx.item and ctx.item.source_name == 'LSP' and c_highlight then
        local ok, color_item = pcall(
          c_highlight.format, ctx.item.documentation, { kind = ctx.kind }
        )
        if ok and type(color_item) == 'table' and (color_item.abbr or '') ~= '' then
          icon = color_item.abbr
        end
      end

      -- nvim-web-devicons: file-type icon for Path completions
      if ctx.source_name == 'Path' then
        local devicons = try_require('nvim-web-devicons')
        if devicons and ctx.label then
          local ok, dev_icon = pcall(devicons.get_icon, ctx.label)
          if ok and dev_icon then
            icon = dev_icon .. ' '
          end
        end
      end

      -- Inline colour swatch for Color-kind items (Tailwind, CSS, etc.)
      if ctx.kind == 'Color' then
        local hex = nil
        local doc = ctx.item and ctx.item.documentation

        if type(doc) == 'string' then
          hex = doc:match '^#(%x%x%x%x%x%x)$'
        elseif type(doc) == 'table'
          and doc.kind == 'markdown'
          and type(doc.value) == 'string'
        then
          hex = doc.value:match '^#(%x%x%x%x%x%x)$'
        end

        if not hex and type(ctx.label_description) == 'string' then
          hex = ctx.label_description:match '#(%x%x%x%x%x%x)'
        end

        if hex then
          hex = '#' .. hex:upper()
          local hl_name = 'BlinkCmpColor' .. hex:sub(2)
          if vim.fn.hlexists(hl_name) == 0 then
            pcall(vim.api.nvim_set_hl, 0, hl_name, {
              fg = get_contrast_fg(hex),
              bg = hex,
            })
          end
          ctx.highlight = hl_name
          icon = '󱓻'
        end
      end

      return ' ' .. icon .. ' '
    end,

    highlight = function(ctx)
      local highlight = 'BlinkCmpKind' .. (ctx.kind or 'Unknown')

      if ctx.item and ctx.item.source_name == 'LSP' and c_highlight then
        local ok, color_item = pcall(
          c_highlight.format, ctx.item.documentation, { kind = ctx.kind }
        )
        if ok and type(color_item) == 'table' and color_item.abbr_hl_group then
          highlight = color_item.abbr_hl_group
        end
      end

      return highlight
    end,
  },

  -- ── label ──────────────────────────────────────────────────────────────────
  label = {
    width = { fill = true, max = 60 },

    text = function(ctx)
      local colorful = try_require('colorful-menu')
      if colorful then
        local ok, info = pcall(colorful.blink_highlights, ctx)
        if ok and type(info) == 'table' and info.label then
          return info.label
        end
      end
      return ctx.label or ''
    end,

    highlight = function(ctx)
      local highlights = {}

      local colorful = try_require('colorful-menu')
      if colorful then
        local ok, info = pcall(colorful.blink_highlights, ctx)
        if ok and type(info) == 'table' and type(info.highlights) == 'table' then
          highlights = info.highlights
        end
      end

      for _, idx in ipairs(ctx.label_matched_indices or {}) do
        table.insert(highlights, { idx, idx + 1, group = 'BlinkCmpLabelMatch' })
      end

      if ctx.deprecated then
        table.insert(highlights, { 1, -1, group = 'BlinkCmpLabelDeprecated' })
      end

      return highlights
    end,
  },
}

-- ── Plugin spec ───────────────────────────────────────────────────────────────

return {
  'saghen/blink.cmp',
  event   = 'VimEnter',
  version = '1.*',
  --- @module 'blink.cmp'
  opts = {
    keymap = {
      preset = 'super-tab',

      ['<tab>'] = {
        function(cmp)
          if cmp.snippet_active() then
            return cmp.accept()
          else
            return cmp.select_and_accept()
          end
        end,
        'snippet_forward',
        'fallback',
      },
    },

    appearance = {
      nerd_font_variant = 'mono',
      kind_icons        = kind_icons,
    },

    completion = {
      trigger = {
        show_on_backspace_after_accept = true,
        show_on_insert                 = true,
        show_on_trigger_character      = true,
      },

      documentation = {
        auto_show          = true,
        auto_show_delay_ms = 400,
        window             = { border = 'rounded' },
        treesitter_highlighting = true,
      },

      menu = {
        auto_show          = true,
        auto_show_delay_ms = 0,
        enabled            = true,
        min_width          = 15,
        max_height         = 10,
        border             = 'rounded',
        winhighlight       = 'Normal:Normal,FloatBorder:None,CursorLine:Visual,Search:None',
        draw = {
          padding  = { 0, 0 },
          columns  = { { 'kind_icon' }, { 'kind' }, { 'label' } },
          components = components,
        },
      },

      accept = {
        auto_brackets = { enabled = true },
      },

      list = {
        selection = {
          preselect = function(_ctx)
            local ok, blink = pcall(require, 'blink.cmp')
            return ok and not blink.snippet_active { direction = 1 }
          end,
          auto_insert = function(_ctx)
            return vim.bo.filetype == 'markdown'
          end,
        },
      },
    },

    sources = {
      default = function()
        local ok, node = pcall(vim.treesitter.get_node)
        if ok and node and vim.tbl_contains(
          { 'comment', 'line_comment', 'block_comment' }, node:type()
        ) then
          return { 'buffer' }
        end
        return { 'lazydev', 'lsp', 'path', 'buffer', 'snippets' }
      end,

      per_filetype = {
        lua = { inherit_defaults = true, 'lazydev' },
      },

      providers = {
        buffer = {
          name        = 'buffer',
          max_items   = 4,
          score_offset = -2,
        },
        lazydev = {
          name        = 'LazyDev',
          module      = 'lazydev.integrations.blink',
          score_offset = 100,
        },
        snippets = {
          name        = 'snippets',
          score_offset = -5,
        },
      },
    },

    snippets = { preset = 'luasnip' },

    fuzzy = { implementation = 'lua' },

    signature = {
      enabled = true,
      window  = {
        min_width   = 1,
        max_width   = 100,
        max_height  = 10,
        border      = 'rounded',
        winblend    = 0,
        winhighlight = 'Normal:BlinkCmpSignatureHelp,FloatBorder:BlinkCmpSignatureHelpBorder',
        scrollbar   = false,
        direction_priority = { 'n', 's' },
      },
      trigger = {
        enabled                       = true,
        show_on_keyword               = true,
        show_on_trigger_character     = true,
        show_on_insert                = true,
        show_on_insert_on_trigger_character = true,
        blocked_trigger_characters    = {},
        blocked_retrigger_characters  = {},
      },
    },
  },


  opts_extend = {
    'sources.default',
    'sources.providers',
  },
}
