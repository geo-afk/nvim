-- =============================================================================
--  plugins/completion.lua  ·  blink.cmp
--
--  Replaces the native 'autocomplete' option (set false in options.lua).
--  All colour / icon / LazyDev integration preserved from the user's config.
-- =============================================================================

vim.pack.add({
  { src = "https://github.com/saghen/blink.cmp", version = vim.version.range("^1") },
  { src = "https://github.com/xzbdmw/colorful-menu.nvim" },
})

-- ── Helpers ───────────────────────────────────────────────────────────────────
local function get_contrast_fg(hex)
  hex = hex:gsub("#", "")
  if #hex ~= 6 then
    return "#FFFFFF"
  end
  local r = (tonumber(hex:sub(1, 2), 16) or 0) / 255
  local g = (tonumber(hex:sub(3, 4), 16) or 0) / 255
  local b = (tonumber(hex:sub(5, 6), 16) or 0) / 255
  local lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
  return lum > 0.5 and "#000000" or "#FFFFFF"
end

local function try_require(mod)
  local ok, r = pcall(require, mod)
  return ok and r or nil
end

local c_highlight = try_require("nvim-highlight-colors")

-- ── Kind icons ────────────────────────────────────────────────────────────────
local kind_icons = {
  Text = "󰉿",
  Method = "󰆧",
  Function = "󰊕",
  Constructor = "󰒓",
  Field = "󰜢",
  Variable = "󰀫 ",
  Class = "󱡠",
  Interface = "󱡠",
  Module = "󰅩",
  Property = "󰖷",
  Color = "󰏘",
  Reference = "󰬲",
  Folder = "󰉋",
  Constant = "󰏿",
  Event = "󱐋",
  Copilot = "",
  TabNine = "󰏚 ",
  Unknown = "󰅗",
  Unit = "󰑭",
  Value = "󰎠",
  Enum = "",
  Keyword = "󰌋",
  Snippet = "",
  File = "󰈙",
  EnumMember = "",
  Struct = "󰙅",
  Operator = "󰆕",
  TypeParameter = "󰊄",
}

-- ── Draw components ───────────────────────────────────────────────────────────

-- Helper to get icon & highlight from mini.icons

-- Helper to get icon with proper priority:
-- 1. kind_icons (if provided and has entry for this kind)
-- 2. mini.icons (if available)
-- 3. fallback default icon
local function get_icon_with_priority(kind, label, ctx, kind_icons_table)
  -- Priority 1: Check kind_icons if it exists for this kind
  if kind_icons_table and kind_icons_table[kind] then
    return kind_icons_table[kind] .. " ", nil
  end

  -- Priority 2: Try mini.icons
  local mini_icons = try_require("mini.icons")
  if mini_icons then
    -- For path sources: use file/directory icon
    if ctx and ctx.source_name == "Path" and label then
      local icon, hl = mini_icons.get("file", label)
      if icon then
        return icon .. " ", hl
      end
    end

    -- For LSP kinds
    local icon, hl = mini_icons.get("lsp", kind)
    if icon then
      return icon .. " ", hl
    end
  end

  -- Priority 3: Default fallback
  return "󰣇 ", nil
end

-- Your original kind_icons (preserved)

local components = {
  kind_icon = {
    text = function(ctx)
      -- Default icon (space + default icon + space)
      local icon = " " .. (kind_icons[ctx.kind] or "󰣇") .. " "

      -- Get icon with priority system (kind_icons first, then mini.icons)
      local priority_icon, _ = get_icon_with_priority(ctx.kind, ctx.label, ctx, kind_icons)
      if priority_icon then
        icon = " " .. priority_icon
      end

      -- Special handling for nvim-highlight-colors (preserved)
      if ctx.item and ctx.item.source_name == "LSP" and c_highlight then
        local ok2, ci = pcall(c_highlight.format, ctx.item.documentation, { kind = ctx.kind })
        if ok2 and type(ci) == "table" and (ci.abbr or "") ~= "" then
          icon = " " .. ci.abbr .. " "
        end
      end

      -- Color preview (preserved and using your contrast function)
      if ctx.kind == "Color" then
        local hex = nil
        local doc = ctx.item and ctx.item.documentation
        if type(doc) == "string" then
          hex = doc:match("^#(%x%x%x%x%x%x)$")
        elseif type(doc) == "table" and doc.kind == "markdown" and type(doc.value) == "string" then
          hex = doc.value:match("^#(%x%x%x%x%x%x)$")
        end
        if not hex and type(ctx.label_description) == "string" then
          hex = ctx.label_description:match("#(%x%x%x%x%x%x)")
        end
        if hex then
          hex = "#" .. hex:upper()
          local hl_name = "BlinkCmpColor" .. hex:sub(2)
          if vim.fn.hlexists(hl_name) == 0 then
            pcall(vim.api.nvim_set_hl, 0, hl_name, { fg = get_contrast_fg(hex), bg = hex })
          end
          ctx.highlight = hl_name
          icon = " 󱓻 " -- color preview icon
        end
      end

      return " " .. icon .. " "
    end,
    highlight = function(ctx)
      -- Try kind_icons highlight first
      local _, hl = get_icon_with_priority(ctx.kind, ctx.label, ctx, kind_icons)
      if hl then
        return hl
      end

      -- Then nvim-highlight-colors
      local highlight = "BlinkCmpKind" .. (ctx.kind or "Unknown")
      if ctx.item and ctx.item.source_name == "LSP" and c_highlight then
        local ok2, ci = pcall(c_highlight.format, ctx.item.documentation, { kind = ctx.kind })
        if ok2 and type(ci) == "table" and ci.abbr_hl_group then
          highlight = ci.abbr_hl_group
        end
      end
      return highlight
    end,
  },

  label = {
    width = { fill = true, max = 60 },
    text = function(ctx)
      local colorful = try_require("colorful-menu")
      if colorful then
        local ok2, info = pcall(colorful.blink_highlights, ctx)
        if ok2 and type(info) == "table" and info.label then
          return info.label
        end
      end
      return ctx.label or ""
    end,
    highlight = function(ctx)
      local highlights = {}
      local colorful = try_require("colorful-menu")
      if colorful then
        local ok2, info = pcall(colorful.blink_highlights, ctx)
        if ok2 and type(info) == "table" and type(info.highlights) == "table" then
          highlights = info.highlights
        end
      end
      for _, idx in ipairs(ctx.label_matched_indices or {}) do
        table.insert(highlights, { idx, idx + 1, group = "BlinkCmpLabelMatch" })
      end
      if ctx.deprecated then
        table.insert(highlights, { 1, -1, group = "BlinkCmpLabelDeprecated" })
      end
      return highlights
    end,
  },
}

-- ── Setup ─────────────────────────────────────────────────────────────────────
local ok, blink = pcall(require, "blink.cmp")
if not ok then
  error("blink.cmp binary/library not ready yet")
end

blink.setup({
  keymap = {
    preset = "super-tab",
    -- Note: overrides the super-tab preset's default <C-k> (show_signature/hide_signature/fallback).
    -- Manual signature-help toggling is unavailable; signature help still triggers automatically.
    ["<C-k>"] = {
      "show",
      "show_documentation",
      "hide_documentation",
      function(cmp)
        return cmp.show({
          initial_selected_item_idx = 1,
          callback = function()
            pcall(function()
              require("blink.cmp").show_documentation()
            end)
          end,
        })
      end,
    },
    -- <Tab> intentionally left to the super-tab preset (identical accept/select_and_accept logic).
  },

  appearance = {
    nerd_font_variant = "mono",
    kind_icons = kind_icons, -- Your original kind_icons table
  },

  completion = {
    trigger = {
      show_on_backspace_after_accept = true,
      show_on_insert = true,
      show_on_trigger_character = true,
    },
    documentation = {
      auto_show = true,
      auto_show_delay_ms = 400,
      window = { border = "rounded" },
      treesitter_highlighting = true,
    },
    menu = {
      auto_show = true,
      auto_show_delay_ms = 0,
      enabled = true,
      min_width = 15,
      max_height = 10,
      border = "rounded",
      winhighlight = "Normal:Normal,FloatBorder:None,CursorLine:Visual,Search:None",
      draw = {
        padding = { 0, 0 },
        columns = { { "kind_icon" }, { "kind" }, { "label" } },
        components = components,
      },
    },
    accept = { auto_brackets = { enabled = true } },
    list = {
      selection = {
        preselect = function(_ctx)
          local ok2, b = pcall(require, "blink.cmp")
          return ok2 and not b.snippet_active({ direction = 1 })
        end,
        auto_insert = function(_ctx)
          return vim.bo.filetype == "markdown"
        end,
      },
    },
  },

  sources = {
    default = function()
      local ok2, node = pcall(vim.treesitter.get_node)
      if ok2 and node and vim.tbl_contains({ "comment", "line_comment", "block_comment" }, node:type()) then
        return { "buffer" }
      end
      return { "lsp", "path", "buffer", "snippets" }
    end,
    -- go/gomod/gowork/gotmpl entries reorder providers vs. the default() function output;
    -- they don't add providers beyond what default() already returns for these filetypes.
    per_filetype = {
      lua = { inherit_defaults = true, "lazydev" },
      go = { inherit_defaults = true, "lsp", "path", "snippets", "buffer" },
      gomod = { inherit_defaults = true, "lsp", "path", "buffer" },
      gowork = { inherit_defaults = true, "lsp", "path", "buffer" },
      gotmpl = { inherit_defaults = true, "lsp", "path", "snippets", "buffer" },
    },
    providers = {
      buffer = { name = "buffer", max_items = 4, score_offset = -2 },
      lazydev = { name = "LazyDev", module = "lazydev.integrations.blink", score_offset = 100 },
      snippets = { name = "snippets", score_offset = -5 },
    },
  },

  snippets = { preset = "luasnip" },
  fuzzy = { implementation = "lua" },

  signature = {
    enabled = true,
    window = {
      min_width = 1,
      max_width = 100,
      max_height = 10,
      border = "rounded",
      winblend = 0,
      winhighlight = "Normal:BlinkCmpSignatureHelp,FloatBorder:BlinkCmpSignatureHelpBorder",
      scrollbar = false,
      direction_priority = { "n", "s" },
    },
    trigger = {
      enabled = true,
      show_on_keyword = true,
      show_on_trigger_character = true,
      show_on_insert = true,
      show_on_insert_on_trigger_character = true,
    },
  },
})
