-- =============================================================================
--  plugins/color-highlight.lua  ·  nvim-highlight-colors (nhc-forked)
--
--  Renders inline colour swatches for hex codes, rgb(), named colours,
--  and Tailwind classes. Also used by blink.cmp for colour-kind items.
-- =============================================================================

vim.pack.add({ { src = "https://github.com/geo-afk/nhc-forked" } })

local ok, nhc = pcall(require, "nvim-highlight-colors")
if not ok then
  return
end

nhc.setup({
  render = "background",
  enable_virtual_text = true,
  enable_named_colors = true,
  enable_tailwind = true,
  virtual_symbol = "󱓻 ",
  virtual_symbol_prefix = "",
  virtual_symbol_suffix = "",
  -- "inline" mimics VS Code style; "eol" = end of line; "eow" = end of word
  virtual_symbol_position = "inline",
})
