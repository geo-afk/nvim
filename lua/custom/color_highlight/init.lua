-- init.lua
-- Main module file that brings everything together

local api = vim.api
local fn = vim.fn

local patterns = require 'custom.color_highlight.patterns'
local converters = require 'custom.color_highlight.converters'
local color_helpers = require 'custom.color_highlight.color_helpers'
local render_options = require 'custom.color_highlight.render_options'

local M = {}

-- Re-export helper functions
M.get_rgb_values = color_helpers.get_rgb_values
M.get_hsl_values = color_helpers.get_hsl_values
M.get_hsl_without_func_values = color_helpers.get_hsl_without_func_values
M.get_css_named_color_pattern = color_helpers.get_css_named_color_pattern
M.get_tailwind_named_color_pattern = color_helpers.get_tailwind_named_color_pattern
M.get_css_named_color_value = color_helpers.get_css_named_color_value
M.get_ansi_named_color_value = color_helpers.get_ansi_named_color_value
M.get_tailwind_named_color_value = color_helpers.get_tailwind_named_color_value
M.get_css_var_color = color_helpers.get_css_var_color
M.get_custom_color = color_helpers.get_custom_color

-- Default configuration
local options = {
  -- Original options
  render = render_options.background,
  enable_virtual_text = false,
  enable_hex = true,
  enable_rgb = true,
  enable_hsl = true,
  enable_hsl_without_function = true,
  enable_var_usage = true,
  enable_named_colors = true,
  enable_short_hex = true,
  enable_tailwind = false,
  enable_ansi = false,
  custom_colors = nil,
  virtual_symbol = '■',
  virtual_symbol_prefix = '',
  virtual_symbol_suffix = ' ',
  virtual_symbol_position = 'inline',
  exclude_filetypes = {},
  exclude_buftypes = {},
  exclude_buffer = function(bufnr) end,

  -- Colorify options
  enabled = true,
  mode = 'virtual', -- 'fg', 'bg', 'virtual', 'bg_n_virtual'
  virt_text = '󱓻 ',
  border_radius = 0.3, -- 0.0 to 0.5, controls roundness of background highlight
  highlight = {
    hex = true,
    lspvars = true,
  },
}

local ns_id = api.nvim_create_namespace 'nvim-highlight-colors'

-- Cache for format function
local format_cache = {}

-- Utility functions
local utils = {}

-- Check if a hex color is dark (for choosing foreground in 'bg' mode)
function utils.is_dark(hex)
  hex = hex:gsub('#', '')
  local r = tonumber(hex:sub(1, 2), 16)
  local g = tonumber(hex:sub(3, 4), 16)
  local b = tonumber(hex:sub(5, 6), 16)
  local brightness = (r * 299 + g * 587 + b * 114) / 1000
  return brightness < 128
end

-- Create or reuse a highlight group for a hex color
function utils.add_hl(hex, mode)
  mode = mode or options.mode
  local name = 'NvimHighlightColors_' .. hex:sub(2)
  local is_bg_mode = mode == 'bg' or mode == 'bg_n_virtual'
  local is_virtual_only = mode == 'virtual'

  if api.nvim_get_hl(0, { name = name }).fg then
    return name
  end

  local fg = hex
  local bg = hex

  if is_bg_mode then
    fg = utils.is_dark(hex) and '#FFFFFF' or '#000000'
  elseif is_virtual_only or mode == 'fg' then
    bg = 'NONE'
  end

  api.nvim_set_hl(0, name, { fg = fg, bg = bg })
  return name
end

-- Create rounded background highlight using blend
function utils.add_hl_with_blend(hex, blend_amount)
  local base_name = 'NvimHighlightColors_' .. hex:sub(2)
  local name = base_name .. '_blend_' .. blend_amount

  if api.nvim_get_hl(0, { name = name }).fg then
    return name
  end

  local fg = utils.is_dark(hex) and '#FFFFFF' or '#000000'
  api.nvim_set_hl(0, name, { fg = fg, bg = hex, blend = blend_amount })
  return name
end

-- Apply rounded background effect by setting extmarks with varying blend
local function apply_rounded_bg(buf, line_nr, col, hex, text_len)
  local hl_group = utils.add_hl(hex, 'bg')

  if options.border_radius == 0 then
    local opts = {
      end_col = col + text_len,
      hl_group = hl_group,
      hl_mode = 'combine',
      priority = 100,
    }
    pcall(api.nvim_buf_set_extmark, buf, ns_id, line_nr, col, opts)
    return hl_group
  end

  local fade_chars = math.max(1, math.floor(text_len * options.border_radius))

  for i = 0, text_len - 1 do
    local blend = 0

    if i < fade_chars then
      blend = math.floor(100 * (1 - (i / fade_chars)))
    elseif i >= text_len - fade_chars then
      blend = math.floor(100 * (1 - ((text_len - 1 - i) / fade_chars)))
    end

    local char_hl = blend > 0 and utils.add_hl_with_blend(hex, blend) or hl_group

    local opts = {
      end_col = col + i + 1,
      hl_group = char_hl,
      hl_mode = 'combine',
      hl_eol = false,
      priority = 100,
    }

    pcall(api.nvim_buf_set_extmark, buf, ns_id, line_nr, col + i, opts)
  end

  return hl_group
end

-- Apply highlighting based on mode
local function apply_highlight(buf, line_nr, col, hex, text_len)
  local end_col = col + text_len
  local hl_group = utils.add_hl(hex)

  if options.mode == 'bg_n_virtual' then
    -- Apply background first
    apply_rounded_bg(buf, line_nr, col, hex, text_len)

    -- Then add virtual text at the end
    local virt_opts = {
      virt_text = { { options.virt_text, hl_group } },
      virt_text_pos = 'inline',
      hl_mode = 'combine',
      priority = 200,
    }
    pcall(api.nvim_buf_set_extmark, buf, ns_id, line_nr, end_col, virt_opts)
  elseif options.mode == 'bg' then
    -- Background only
    apply_rounded_bg(buf, line_nr, col, hex, text_len)
  elseif options.mode == 'virtual' then
    -- Virtual text only (inline at the end of the color)
    local virt_opts = {
      virt_text = { { options.virt_text, hl_group } },
      virt_text_pos = 'inline',
      hl_mode = 'combine',
      priority = 200,
    }
    pcall(api.nvim_buf_set_extmark, buf, ns_id, line_nr, end_col, virt_opts)
  elseif options.mode == 'fg' then
    -- Foreground color on the text itself
    local fg_opts = {
      end_col = end_col,
      hl_group = hl_group,
      hl_mode = 'combine',
      priority = 100,
    }
    pcall(api.nvim_buf_set_extmark, buf, ns_id, line_nr, col, fg_opts)
  end
end

-- Get color value with all pattern matching
function M.get_color_value(color, row_offset, custom_colors, enable_short_hex)
  if enable_short_hex and patterns.is_short_hex_color(color) then
    return converters.short_hex_to_hex(color)
  end

  if enable_short_hex and patterns.is_alpha_layer_short_hex(color) then
    return string.sub(converters.short_hex_to_hex(color), 1, 7)
  end

  if patterns.is_alpha_layer_hex(color) then
    return string.sub(color, 1, 7)
  end

  if patterns.is_rgb_color(color) then
    local rgb_table = M.get_rgb_values(color)
    if #rgb_table >= 3 then
      return converters.rgb_to_hex(rgb_table[1], rgb_table[2], rgb_table[3])
    end
  end

  if patterns.is_hsl_color(color) then
    local hsl_table = M.get_hsl_values(color)
    if #hsl_table >= 3 then
      local rgb_table = converters.hsl_to_rgb(hsl_table[1], hsl_table[2], hsl_table[3])
      return converters.rgb_to_hex(rgb_table[1], rgb_table[2], rgb_table[3])
    end
  end

  if patterns.is_hsl_without_func_color(color) then
    local hsl_table = M.get_hsl_without_func_values(color)
    if #hsl_table >= 3 then
      local rgb_table = converters.hsl_to_rgb(hsl_table[1], hsl_table[2], hsl_table[3])
      return converters.rgb_to_hex(rgb_table[1], rgb_table[2], rgb_table[3])
    end
  end

  if patterns.is_named_color({ M.get_css_named_color_pattern() }, color) then
    return M.get_css_named_color_value(color)
  end

  if patterns.is_ansi_color(color) then
    return M.get_ansi_named_color_value(color)
  end

  if patterns.is_named_color({ M.get_tailwind_named_color_pattern() }, color) then
    local tailwind_color = M.get_tailwind_named_color_value(color)
    if tailwind_color ~= nil then
      return tailwind_color
    end
  end

  if row_offset ~= nil and patterns.is_var_color(color) then
    return M.get_css_var_color(color, row_offset)
  end

  if custom_colors ~= nil and patterns.is_custom_color(color, custom_colors) then
    return M.get_custom_color(color, custom_colors)
  end

  local hex_color = color:gsub('0x', '#')

  if patterns.is_hex_color(hex_color) then
    return hex_color
  end

  return nil
end

-- Create highlight name
function M.create_highlight_name(color_value)
  return 'nvim-highlight-colors-' .. string.gsub(color_value, '#', ''):gsub('\\[0-9]*%[', ''):gsub('[!(),%s%.-/%%=:"\'%%[%];#]+', '')
end

-- Highlight colors in a line based on enabled formats
local function highlight_line_colors(buf, line_nr, line_str)
  local colors_found = {}

  -- Hex colors (#RRGGBB)
  if options.enable_hex then
    for col, hex in line_str:gmatch '()(#%x%x%x%x%x%x)%f[^%x]' do
      table.insert(colors_found, { col = col - 1, hex = hex, len = 7 })
    end
  end

  -- Short hex colors (#RGB)
  if options.enable_short_hex then
    for col, hex in line_str:gmatch '()(#%x%x%x)%f[^%x]' do
      if not line_str:match('^#%x%x%x%x%x%x', col) then -- avoid matching part of long hex
        local full_hex = converters.short_hex_to_hex(hex)
        table.insert(colors_found, { col = col - 1, hex = full_hex, len = 4 })
      end
    end
  end

  -- RGB colors
  if options.enable_rgb then
    for col, rgb_match in line_str:gmatch '()(rgba?%s*%([^)]+%))' do
      local hex = M.get_color_value(rgb_match)
      if hex then
        table.insert(colors_found, { col = col - 1, hex = hex, len = #rgb_match })
      end
    end
  end

  -- HSL colors
  if options.enable_hsl then
    for col, hsl_match in line_str:gmatch '()(hsla?%s*%([^)]+%))' do
      local hex = M.get_color_value(hsl_match)
      if hex then
        table.insert(colors_found, { col = col - 1, hex = hex, len = #hsl_match })
      end
    end
  end

  -- HSL without function
  if options.enable_hsl_without_function then
    for col, hsl_match in line_str:gmatch '()(%d+%s+%d+%%%s+%d+%%)' do
      local hex = M.get_color_value(hsl_match)
      if hex then
        table.insert(colors_found, { col = col - 1, hex = hex, len = #hsl_match })
      end
    end
  end

  -- Named colors (be careful not to match random words)
  if options.enable_named_colors then
    -- Only match named colors that are likely to be actual color values
    -- (e.g., surrounded by spaces, quotes, or at word boundaries)
    for col, color_name in line_str:gmatch '()(%a+)' do
      -- Check if it's a valid CSS color name
      local hex = M.get_css_named_color_value(color_name)
      if hex then
        -- Verify it's in a context that suggests it's a color value
        local before = col > 1 and line_str:sub(col - 1, col - 1) or ' '
        local after_pos = col + #color_name
        local after = after_pos <= #line_str and line_str:sub(after_pos, after_pos) or ' '

        -- Check for color context (after :, =, (, etc.)
        if before:match '[:%s=%(,;"\']' or after:match '[%s,;%)"\']' then
          table.insert(colors_found, { col = col - 1, hex = hex, len = #color_name })
        end
      end
    end
  end

  -- Tailwind colors
  if options.enable_tailwind then
    for col, tw_match in line_str:gmatch '()([a-z]+%-[0-9]+)' do
      local hex = M.get_tailwind_named_color_value(tw_match)
      if hex then
        table.insert(colors_found, { col = col - 1, hex = hex, len = #tw_match })
      end
    end
  end

  -- ANSI colors
  if options.enable_ansi then
    for col, ansi_match in line_str:gmatch '()(bright?%a+)' do
      local hex = M.get_ansi_named_color_value(ansi_match)
      if hex then
        table.insert(colors_found, { col = col - 1, hex = hex, len = #ansi_match })
      end
    end
  end

  -- Highlight each color found
  for _, color_info in ipairs(colors_found) do
    apply_highlight(buf, line_nr, color_info.col, color_info.hex, color_info.len)
  end
end

-- Highlight LSP-provided colors
local function highlight_lsp_colors(buf, single_line, min_line, max_line)
  if not options.highlight.lspvars then
    return
  end

  local params = { textDocument = vim.lsp.util.make_text_document_params(buf) }

  for _, client in pairs(vim.lsp.get_clients { bufnr = buf }) do
    if client.server_capabilities.colorProvider then
      client.request('textDocument/documentColor', params, function(_, result)
        if not result then
          return
        end

        if single_line ~= nil then
          result = vim.tbl_filter(function(c)
            return c.range.start.line == single_line
          end, result)
        elseif min_line then
          result = vim.tbl_filter(function(c)
            return c.range.start.line >= min_line and c.range['end'].line <= max_line
          end, result)
        end

        for _, color_info in ipairs(result) do
          local c = color_info.color
          local alpha = c.alpha or 1
          if alpha > 1 then
            alpha = alpha / 255
          end

          local hex = string.format('#%02x%02x%02x', math.floor(c.red * alpha * 255), math.floor(c.green * alpha * 255), math.floor(c.blue * alpha * 255))

          local start_pos = color_info.range.start
          local end_pos = color_info.range['end']
          local text_len = end_pos.character - start_pos.character

          apply_highlight(buf, start_pos.line, start_pos.character, hex, text_len)
        end
      end, buf)
    end
  end
end

-- Attach change handler to buffer
local function attach_change_handler(buf)
  if vim.b[buf].nvim_highlight_colors_attached then
    return
  end
  vim.b[buf].nvim_highlight_colors_attached = true

  api.nvim_buf_attach(buf, false, {
    on_bytes = function(_, b, _, start_row, start_col, _, old_end_row, old_end_col, _, _, new_end_col, _)
      if old_end_row == 0 and new_end_col == 0 and old_end_col == 0 then
        return
      end

      local row1, col1 = start_row, start_col
      local row2, col2
      if old_end_row > 0 then
        row2, col2 = start_row + old_end_row, 0
      else
        row2, col2 = start_row, start_col + old_end_col
      end

      if api.nvim_get_mode().mode ~= 'i' then
        col1, col2 = 0, -1
      end

      local marks = api.nvim_buf_get_extmarks(b, ns_id, { row1, col1 }, { row2, col2 }, { overlap = true })
      for _, mark in ipairs(marks) do
        pcall(api.nvim_buf_del_extmark, b, ns_id, mark[1])
      end
    end,
    on_detach = function()
      vim.b[buf].nvim_highlight_colors_attached = nil
      api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)
    end,
  })
end

-- Main colorify function
local function colorify_buffer(buf, event)
  if not options.enabled or not vim.bo[buf].modifiable then
    return
  end

  -- Check exclusions
  local ft = vim.bo[buf].filetype
  local bt = vim.bo[buf].buftype

  if vim.tbl_contains(options.exclude_filetypes, ft) then
    return
  end

  if vim.tbl_contains(options.exclude_buftypes, bt) then
    return
  end

  if options.exclude_buffer(buf) then
    return
  end

  local winid = fn.bufwinid(buf)
  if winid == -1 then
    return
  end

  local min_line = fn.line('w0', winid) - 1
  local max_line = fn.line('w$', winid)

  if event == 'TextChangedI' or event == 'TextChangedP' then
    local cur_line = fn.line '.' - 1
    local cur_str = api.nvim_get_current_line()
    highlight_line_colors(buf, cur_line, cur_str)
    highlight_lsp_colors(buf, cur_line)
    return
  end

  local lines = api.nvim_buf_get_lines(buf, min_line, max_line, false)
  for i, line_str in ipairs(lines) do
    highlight_line_colors(buf, min_line + i - 1, line_str)
  end

  highlight_lsp_colors(buf, nil, min_line, max_line - 1)
  attach_change_handler(buf)
end

-- nvim-cmp format function
function M.format(entry, item)
  item.menu = item.kind
  item.kind = item.abbr
  item.kind_hl_group = ''
  item.abbr = ''

  if item.menu ~= 'Color' then
    return item
  end

  local entryDoc = entry
  if type(entryDoc) == 'table' then
    entryDoc = vim.tbl_get(entry or {}, 'completion_item', 'documentation')
  end
  if type(entryDoc) ~= 'string' then
    return item
  end

  local cached = format_cache[entryDoc]
  if cached == nil then
    local color_hex = M.get_color_value(entryDoc)
    cached = color_hex and { hl_group = M.create_highlight_name('fg-' .. color_hex), color_hex = color_hex } or false
    format_cache[entryDoc] = cached
  end
  if cached then
    vim.api.nvim_set_hl(0, cached.hl_group, { fg = cached.color_hex, default = true })
    item.abbr_hl_group = cached.hl_group
    item.abbr = options.virtual_symbol
  end
  return item
end

-- Setup function
function M.setup(user_options)
  options = vim.tbl_deep_extend('force', options, user_options or {})

  api.nvim_create_autocmd({ 'BufLeave', 'BufWinLeave' }, {
    callback = function(args)
      api.nvim_buf_clear_namespace(args.buf, ns_id, 0, -1)
    end,
  })

  api.nvim_create_autocmd({
    'BufEnter',
    'TextChanged',
    'TextChangedI',
    'TextChangedP',
    'WinScrolled',
    'VimResized',
    'LspAttach',
  }, {
    callback = function(args)
      colorify_buffer(args.buf, args.event)
    end,
  })

  return options
end

function M.get_options()
  return options
end

function M.turn_on()
  options.enabled = true
  -- Re-trigger highlighting for all visible buffers
  for _, win in ipairs(api.nvim_list_wins()) do
    local buf = api.nvim_win_get_buf(win)
    colorify_buffer(buf, 'BufEnter')
  end
end

function M.turn_off()
  options.enabled = false
  -- Clear all highlights
  for _, buf in ipairs(api.nvim_list_bufs()) do
    if api.nvim_buf_is_valid(buf) then
      api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)
    end
  end
end

function M.toggle()
  if options.enabled then
    M.turn_off()
  else
    M.turn_on()
  end
end

return M
