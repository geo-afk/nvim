local api = vim.api
local fn = vim.fn

local M = {}

-- Default configuration
local conf = {
  enabled = true,
  mode = 'virtual', -- 'fg', 'bg', 'virtual', 'bg_n_virtual'
  virt_text = '󱓻 ',
  border_radius = 0.3, -- 0.0 to 0.5, controls roundness of background highlight
  highlight = {
    hex = true,
    lspvars = true,
  },
}

local ns_id = api.nvim_create_namespace 'Color_Highlight'

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
function utils.add_hl(hex)
  local name = 'Colorify_' .. hex:sub(2)
  local is_bg_mode = conf.mode == 'bg' or conf.mode == 'bg_n_virtual'
  local is_virtual_only = conf.mode == 'virtual'

  if api.nvim_get_hl(0, { name = name }).fg then
    return name
  end

  local fg = hex
  local bg = hex

  if is_bg_mode then
    fg = utils.is_dark(hex) and 'white' or 'black'
  elseif is_virtual_only or conf.mode == 'fg' then
    bg = 'NONE'
  end

  api.nvim_set_hl(0, name, { fg = fg, bg = bg })
  return name
end

-- Create rounded background highlight using blend
function utils.add_hl_with_blend(hex, blend_amount)
  local base_name = 'Colorify_' .. hex:sub(2)
  local name = base_name .. '_blend_' .. blend_amount

  if api.nvim_get_hl(0, { name = name }).fg then
    return name
  end

  local fg = utils.is_dark(hex) and 'white' or 'black'
  api.nvim_set_hl(0, name, { fg = fg, bg = hex, blend = blend_amount })
  return name
end

-- Check if a position already has the expected highlight/extmark
function utils.needs_update(buf, line, col, hl_group, opts)
  local marks = api.nvim_buf_get_extmarks(buf, ns_id, { line, col }, { line, opts.end_col or col + 1 }, { details = true, limit = 1 })
  if #marks == 0 then
    return true
  end
  local mark = marks[1]
  opts.id = mark[1] -- for potential update
  local existing_hl = mark[4].hl_group or (mark[4].virt_text and mark[4].virt_text[1] and mark[4].virt_text[1][2])
  return hl_group ~= existing_hl
end

-- Apply rounded background effect by setting extmarks with varying blend
local function apply_rounded_bg(buf, line_nr, col, hex, text_len)
  local hl_group = utils.add_hl(hex)

  if conf.border_radius == 0 then
    -- No rounding, just apply normal background
    local opts = {
      end_col = col + text_len,
      hl_group = hl_group,
    }
    if utils.needs_update(buf, line_nr, col, hl_group, opts) then
      api.nvim_buf_set_extmark(buf, ns_id, line_nr, col, opts)
    end
    return hl_group
  end

  -- Calculate fade zones based on border_radius (0.0 to 0.5)
  -- border_radius of 0.5 means half the text is faded on each side
  local fade_chars = math.max(1, math.floor(text_len * conf.border_radius))

  -- Apply fading on edges
  for i = 0, text_len - 1 do
    local blend = 0

    -- Left edge fade
    if i < fade_chars then
      blend = math.floor(100 * (1 - (i / fade_chars)))
    -- Right edge fade
    elseif i >= text_len - fade_chars then
      blend = math.floor(100 * (1 - ((text_len - 1 - i) / fade_chars)))
    end

    local char_hl = blend > 0 and utils.add_hl_with_blend(hex, blend) or hl_group

    local opts = {
      end_col = col + i + 1,
      hl_group = char_hl,
      hl_eol = false,
    }

    pcall(api.nvim_buf_set_extmark, buf, ns_id, line_nr, col + i, opts)
  end

  return hl_group
end

-- Highlight hex colors (#rrggbb) in a line
local function highlight_hex(buf, line_nr, line_str)
  for col, hex in line_str:gmatch '()(#%x%x%x%x%x%x)' do
    col = col - 1
    local hl_group = utils.add_hl(hex)
    local end_col = col + 7

    if conf.mode == 'bg_n_virtual' then
      -- Apply rounded background
      apply_rounded_bg(buf, line_nr, col, hex, 7)

      -- Add virtual text symbol
      local opts = {
        virt_text_pos = 'inline',
        virt_text = { { conf.virt_text, hl_group } },
        hl_mode = 'combine',
      }
      pcall(api.nvim_buf_set_extmark, buf, ns_id, line_nr, end_col, opts)
    elseif conf.mode == 'bg' then
      -- Rounded background only
      apply_rounded_bg(buf, line_nr, col, hex, 7)
    else
      -- Original modes (fg, virtual)
      local opts = {
        end_col = end_col,
        hl_group = (conf.mode ~= 'virtual') and hl_group or nil,
        virt_text_pos = (conf.mode == 'virtual') and 'inline' or nil,
        virt_text = (conf.mode == 'virtual') and { { conf.virt_text, hl_group } } or nil,
      }

      if utils.needs_update(buf, line_nr, col, hl_group, opts) then
        api.nvim_buf_set_extmark(buf, ns_id, line_nr, col, opts)
      end
    end
  end
end

-- Highlight LSP-provided colors (documentColor request)
local function highlight_lsp_colors(buf, single_line, min_line, max_line)
  if not conf.highlight.lspvars then
    return
  end

  local params = { textDocument = vim.lsp.util.make_text_document_params(buf) }

  for _, client in pairs(vim.lsp.get_clients { bufnr = buf }) do
    if client.server_capabilities.colorProvider then
      client.request('textDocument/documentColor', params, function(_, result)
        if not result then
          return
        end

        -- Filter by line/range if requested
        if single_line then
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
          end -- Normalize if needed

          local hex = string.format('#%02x%02x%02x', math.floor(c.red * alpha * 255), math.floor(c.green * alpha * 255), math.floor(c.blue * alpha * 255))

          local hl_group = utils.add_hl(hex)

          local start_pos = color_info.range.start
          local end_pos = color_info.range['end']
          local text_len = end_pos.character - start_pos.character

          if conf.mode == 'bg_n_virtual' then
            -- Apply rounded background
            apply_rounded_bg(buf, start_pos.line, start_pos.character, hex, text_len)

            -- Add virtual text symbol
            local opts = {
              virt_text_pos = 'inline',
              virt_text = { { conf.virt_text, hl_group } },
              hl_mode = 'combine',
            }
            pcall(api.nvim_buf_set_extmark, buf, ns_id, start_pos.line, end_pos.character, opts)
          elseif conf.mode == 'bg' then
            -- Rounded background only
            apply_rounded_bg(buf, start_pos.line, start_pos.character, hex, text_len)
          else
            -- Original modes
            local opts = {
              end_col = end_pos.character,
              hl_group = (conf.mode ~= 'virtual') and hl_group or nil,
              virt_text_pos = (conf.mode == 'virtual') and 'inline' or nil,
              virt_text = (conf.mode == 'virtual') and { { conf.virt_text, hl_group } } or nil,
            }

            if utils.needs_update(buf, start_pos.line, start_pos.character, hl_group, opts) then
              pcall(api.nvim_buf_set_extmark, buf, ns_id, start_pos.line, start_pos.character, opts)
            end
          end
        end
      end, buf)
    end
  end
end

-- Clear extmarks in changed regions on buffer changes
local function attach_change_handler(buf)
  if vim.b[buf].colorify_attached then
    return
  end
  vim.b[buf].colorify_attached = true

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

      -- In normal mode, clear whole lines for simplicity
      if api.nvim_get_mode().mode ~= 'i' then
        col1, col2 = 0, -1
      end

      local marks = api.nvim_buf_get_extmarks(b, ns_id, { row1, col1 }, { row2, col2 }, { overlap = true })
      for _, mark in ipairs(marks) do
        api.nvim_buf_del_extmark(b, ns_id, mark[1])
      end
    end,
    on_detach = function()
      vim.b[buf].colorify_attached = nil
      api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)
    end,
  })
end

-- Main function to colorify visible/current lines
local function colorify_buffer(buf, event)
  if not conf.enabled or not vim.bo[buf].modifiable then
    return
  end -- Skip unmodifiable/special buffers

  local winid = fn.bufwinid(buf)
  if winid == -1 then
    return
  end

  local min_line = fn.line('w0', winid) - 1
  local max_line = fn.line('w$', winid) -- No +1 needed, get_lines is exclusive end

  if event == 'TextChangedI' or event == 'TextChangedP' then
    -- Only current line in insert mode for performance
    local cur_line = fn.line '.' - 1
    local cur_str = api.nvim_get_current_line()

    if conf.highlight.hex then
      highlight_hex(buf, cur_line, cur_str)
    end
    highlight_lsp_colors(buf, cur_line)
    return
  end

  -- Full visible range
  local lines = api.nvim_buf_get_lines(buf, min_line, max_line, false)

  if conf.highlight.hex then
    for i, line_str in ipairs(lines) do
      highlight_hex(buf, min_line + i - 1, line_str)
    end
  end

  highlight_lsp_colors(buf, nil, min_line, max_line - 1)

  attach_change_handler(buf)
end

-- Setup function (call this to enable)
function M.setup(user_conf)
  if user_conf then
    conf = vim.tbl_deep_extend('force', conf, user_conf)
  end

  -- Clear any old extmarks on leave/detach
  api.nvim_create_autocmd({ 'BufLeave', 'BufWinLeave' }, {
    callback = function(args)
      api.nvim_buf_clear_namespace(args.buf, ns_id, 0, -1)
    end,
  })

  -- Main autocmds to trigger colorifying
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
end

return M
