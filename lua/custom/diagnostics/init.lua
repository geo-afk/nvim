local M = {}

-- ============================================================================
-- Collapse multiple diagnostic signs into one sign per severity on each line
-- ============================================================================
local function setup_sign_collapsing()
  local ns = vim.api.nvim_create_namespace 'collapse_signs'
  local orig_signs_handler = vim.diagnostic.handlers.signs

  vim.diagnostic.handlers.signs = {
    show = function(_, bufnr, _, opts)
      local diagnostics = vim.diagnostic.get(bufnr)

      local signs_per_severity_per_line = {}
      for _, d in ipairs(diagnostics) do
        local lnum = d.lnum
        local severity = d.severity
        signs_per_severity_per_line[lnum] = signs_per_severity_per_line[lnum] or {}
        signs_per_severity_per_line[lnum][severity] = signs_per_severity_per_line[lnum][severity] or {}
        table.insert(signs_per_severity_per_line[lnum][severity], d)
      end

      local filtered_diagnostics = {}
      for _, signs_per_line in pairs(signs_per_severity_per_line) do
        for _, signs_per_severity in pairs(signs_per_line) do
          table.insert(filtered_diagnostics, signs_per_severity[1])
        end
      end

      orig_signs_handler.show(ns, bufnr, filtered_diagnostics, opts)
    end,

    hide = function(_, bufnr)
      orig_signs_handler.hide(ns, bufnr)
    end,
  }
end

-- ============================================================================
-- STATE
-- ============================================================================
local api = vim.api
local ns_id = api.nvim_create_namespace 'pretty_inline_diagnostics'
local enabled = true
local config = {}
local attached_buffers = {}
local debounce_timer = nil

-- ============================================================================
-- ENHANCED ICONS & SEVERITY NAMES
-- ============================================================================

local SEVERITY_ICONS = {
  [vim.diagnostic.severity.ERROR] = '󰅚',
  [vim.diagnostic.severity.WARN] = '󰀪',
  [vim.diagnostic.severity.INFO] = '󰋽',
  [vim.diagnostic.severity.HINT] = '󰌶',
}

local SEVERITY_NAMES = {
  [vim.diagnostic.severity.ERROR] = 'Error',
  [vim.diagnostic.severity.WARN] = 'Warn',
  [vim.diagnostic.severity.INFO] = 'Info',
  [vim.diagnostic.severity.HINT] = 'Hint',
}

local SEVERITY_HL = {
  [vim.diagnostic.severity.ERROR] = 'DiagnosticVirtualTextError',
  [vim.diagnostic.severity.WARN] = 'DiagnosticVirtualTextWarn',
  [vim.diagnostic.severity.INFO] = 'DiagnosticVirtualTextInfo',
  [vim.diagnostic.severity.HINT] = 'DiagnosticVirtualTextHint',
}

-- ============================================================================
-- DEFAULT CONFIG
-- ============================================================================
local DEFAULT_CONFIG = {
  position = 'eol', -- 'eol' | 'above' | 'below'

  preset = 'modern', -- modern, minimal, powerline, ghost

  -- Smart truncation for long messages
  eol_max_length = 100, -- Max characters before truncation (0 = no truncation)
  truncate_multiline = true, -- Automatically remove line breaks
  show_source = true,
  show_code = true, -- Show error code (e.g., "E123")

  -- Right-aligned wrapping for EOL mode (NEW!)
  right_align_wrapped = true, -- Keep wrapped lines aligned to the right
  wrap_at_column = 100, -- Where to wrap long messages
  min_right_margin = 5, -- Minimum space from right edge

  -- Message prioritization - what to show first
  priority_order = { 'code', 'severity', 'message', 'source' },

  -- For above/below position
  show_code_snippet = false,
  max_diagnostics = nil,

  throttle_ms = 100,
  severity_sort = true,

  severities = {
    [vim.diagnostic.severity.ERROR] = true,
    [vim.diagnostic.severity.WARN] = true,
    [vim.diagnostic.severity.INFO] = true,
    [vim.diagnostic.severity.HINT] = true,
  },

  disabled_filetypes = {},

  -- UI Enhancements
  show_diagnostic_count = true, -- Show "(2 errors)" when multiple
  arrow_style = 'modern', -- 'modern', 'classic', 'subtle'
}

local PRESETS = {
  modern = {
    left = ' ▎',
    right = '',
    separator = ' 󰇙 ',
    ellipsis = '…',
  },
  minimal = {
    left = '',
    right = '',
    separator = ' · ',
    ellipsis = '…',
  },
  powerline = {
    left = ' ',
    right = '',
    separator = '  ',
    ellipsis = '…',
  },
  ghost = {
    left = ' ╱ ',
    right = ' ╲',
    separator = ' ∙ ',
    ellipsis = '…',
  },
}

local ARROW_STYLES = {
  modern = '▸',
  classic = '→',
  subtle = '›',
}

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================
local function is_buffer_attached(bufnr)
  return api.nvim_buf_is_valid(bufnr) and vim.tbl_contains(attached_buffers, bufnr)
end

local function get_diagnostics_for_line(bufnr, line_0based)
  if not api.nvim_buf_is_valid(bufnr) then
    return {}
  end
  local diags = vim.diagnostic.get(bufnr, { lnum = line_0based })
  local filtered = vim.tbl_filter(function(d)
    return config.severities[d.severity]
  end, diags)
  if config.severity_sort then
    table.sort(filtered, function(a, b)
      return a.severity < b.severity
    end)
  end
  return filtered
end

local function get_line_text(bufnr, line_0based)
  return api.nvim_buf_get_lines(bufnr, line_0based, line_0based + 1, false)[1] or ''
end

local function get_window_width()
  return api.nvim_win_get_width(0)
end

-- Extract the most important part of a diagnostic message
local function extract_key_message(msg)
  -- Remove common prefixes that add noise
  msg = msg:gsub('^%s*', '') -- Remove leading whitespace
  msg = msg:gsub('\n', ' '):gsub('%s+', ' ') -- Collapse whitespace

  -- Try to get just the first sentence or clause
  local first_sentence = msg:match '^([^.!?]+[.!?])' or msg
  local first_clause = msg:match '^([^;,]+)' or first_sentence

  -- If the first clause is very short, include more context
  if #first_clause < 30 and #msg > #first_clause then
    local extended = msg:match '^(.{1,80}%s)' or msg:sub(1, 80)
    return extended
  end

  return first_clause
end

-- Smart truncation that preserves important information
local function truncate_intelligently(text, max_length, style)
  if max_length == 0 or #text <= max_length then
    return text, false
  end

  -- Try to break at a word boundary
  local truncated = text:sub(1, max_length - 1)
  local last_space = truncated:match '^.*()%s' or #truncated
  truncated = text:sub(1, last_space - 1)

  return truncated .. style.ellipsis, true
end

-- Format diagnostic with priority-based information
local function format_diagnostic_smart(diag, max_width, style)
  local parts = {}
  local icon = SEVERITY_ICONS[diag.severity] or ''

  -- Build parts based on priority order
  for _, part in ipairs(config.priority_order) do
    if part == 'code' and config.show_code and diag.code then
      table.insert(parts, '[' .. tostring(diag.code) .. ']')
    elseif part == 'severity' then
      table.insert(parts, SEVERITY_NAMES[diag.severity])
    elseif part == 'source' and config.show_source and diag.source then
      table.insert(parts, diag.source)
    elseif part == 'message' then
      local msg = diag.message
      if config.truncate_multiline then
        msg = msg:gsub('\n', ' '):gsub('%s+', ' ')
      end

      -- For very long messages, extract just the key part
      if #msg > (max_width or 100) then
        msg = extract_key_message(msg)
      end

      table.insert(parts, msg)
    end
  end

  local full_text = icon .. ' ' .. table.concat(parts, ': ')
  local truncated_text, was_truncated = truncate_intelligently(full_text, max_width, style)

  return truncated_text, SEVERITY_HL[diag.severity], was_truncated
end

-- Calculate right-aligned position for text
local function calculate_right_align_offset(text_width, win_width, line_text_width)
  local available_width = win_width - line_text_width - config.min_right_margin
  return math.max(1, available_width)
end

-- ============================================================================
-- RENDERING - EOL WITH RIGHT-ALIGNED WRAPPING
-- ============================================================================
local function clear_extmarks(bufnr)
  if api.nvim_buf_is_valid(bufnr) then
    pcall(api.nvim_buf_clear_namespace, bufnr, ns_id, 0, -1)
  end
end

local function render_eol_mode(bufnr, line_0based, diags)
  local style = PRESETS[config.preset] or PRESETS.modern
  local line_text = get_line_text(bufnr, line_0based)
  local line_width = vim.fn.strdisplaywidth(line_text)
  local win_width = get_window_width()

  -- Calculate available width for diagnostics
  local available = win_width - line_width - config.min_right_margin - 5

  -- Primary diagnostic on the same line
  local primary = diags[1]
  local main_text, main_hl, was_truncated = format_diagnostic_smart(primary, math.min(available, config.eol_max_length), style)

  -- Add prefix/suffix from style
  local virt_text = {
    { style.left, main_hl },
    { main_text, main_hl },
    { style.right, main_hl },
  }

  -- Show count if multiple diagnostics
  if #diags > 1 and config.show_diagnostic_count then
    local count_text = string.format(' +%d', #diags - 1)
    table.insert(virt_text, { count_text, 'Comment' })
  end

  -- Set the main inline virtual text
  pcall(api.nvim_buf_set_extmark, bufnr, ns_id, line_0based, -1, {
    virt_text = virt_text,
    virt_text_pos = 'eol',
    hl_mode = 'combine',
    priority = 1000,
  })

  -- If there are more diagnostics, show them right-aligned below
  if #diags > 1 then
    local virt_lines = {}

    for i = 2, #diags do
      local diag = diags[i]
      local text, hl = format_diagnostic_smart(diag, config.wrap_at_column, style)

      -- Calculate spacing to right-align
      local text_width = vim.fn.strdisplaywidth(text)
      local needed_spaces = win_width - text_width - config.min_right_margin
      local spacing = string.rep(' ', math.max(0, needed_spaces))

      local line_parts = {
        { spacing, 'Comment' },
        { style.left, hl },
        { text, hl },
        { style.right, hl },
      }

      table.insert(virt_lines, line_parts)
    end

    if #virt_lines > 0 then
      pcall(api.nvim_buf_set_extmark, bufnr, ns_id, line_0based, 0, {
        virt_lines = virt_lines,
        virt_lines_above = false,
        hl_mode = 'combine',
        priority = 999,
      })
    end
  end
end

local function render_virtual_lines(bufnr, line_0based, diags)
  local virt_lines = {}
  local max = config.max_diagnostics and math.min(#diags, config.max_diagnostics) or #diags
  local arrow = ARROW_STYLES[config.arrow_style] or ARROW_STYLES.modern
  local style = PRESETS[config.preset] or PRESETS.modern

  for i = 1, max do
    local diag = diags[i]
    local icon = SEVERITY_ICONS[diag.severity]
    local text, hl = format_diagnostic_smart(diag, config.wrap_at_column, style)

    local line_parts = {}

    -- Add code snippet only on the first diagnostic
    if config.show_code_snippet and i == 1 then
      local code = get_line_text(bufnr, line_0based)
      table.insert(line_parts, { code, 'Normal' })
      table.insert(line_parts, { ' ' .. arrow .. ' ', 'Comment' })
    else
      table.insert(line_parts, { '  ', 'Comment' })
    end

    table.insert(line_parts, { icon .. ' ' .. text, hl })
    table.insert(virt_lines, line_parts)

    -- Add separator between diagnostics
    if i < max and max > 1 then
      table.insert(virt_lines, { { '  ─────', 'Comment' } })
    end
  end

  if config.max_diagnostics and #diags > max then
    table.insert(virt_lines, { { '  … ' .. (#diags - max) .. ' more', 'Comment' } })
  end

  if #virt_lines > 0 then
    pcall(api.nvim_buf_set_extmark, bufnr, ns_id, line_0based, 0, {
      virt_lines = virt_lines,
      virt_lines_above = config.position == 'above',
      hl_mode = 'combine',
      priority = 1000,
    })
  end
end

local function render_diagnostics(bufnr, line_0based)
  if not enabled or not api.nvim_buf_is_valid(bufnr) then
    return
  end
  clear_extmarks(bufnr)

  local diags = get_diagnostics_for_line(bufnr, line_0based)
  if #diags == 0 then
    return
  end

  if config.position == 'eol' then
    render_eol_mode(bufnr, line_0based, diags)
  else
    render_virtual_lines(bufnr, line_0based, diags)
  end
end

-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================
local function on_cursor_moved()
  if debounce_timer then
    debounce_timer:stop()
  end
  debounce_timer = vim.defer_fn(function()
    local bufnr = api.nvim_get_current_buf()
    if not is_buffer_attached(bufnr) then
      return
    end
    local cursor = api.nvim_win_get_cursor(0)
    render_diagnostics(bufnr, cursor[1] - 1)
  end, config.throttle_ms)
end

local function on_diagnostic_changed(args)
  local bufnr = args.buf
  if not is_buffer_attached(bufnr) then
    return
  end
  local cursor = api.nvim_win_get_cursor(0)
  render_diagnostics(bufnr, cursor[1] - 1)
end

-- ============================================================================
-- BUFFER MANAGEMENT
-- ============================================================================
function M.attach(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()
  if not api.nvim_buf_is_valid(bufnr) or is_buffer_attached(bufnr) then
    return
  end

  local ft = vim.bo[bufnr].filetype
  if vim.tbl_contains(config.disabled_filetypes, ft) then
    return
  end

  table.insert(attached_buffers, bufnr)
  local group = api.nvim_create_augroup('PrettyInlineDiags_' .. bufnr, { clear = true })

  api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
    group = group,
    buffer = bufnr,
    callback = on_cursor_moved,
  })

  api.nvim_create_autocmd('DiagnosticChanged', {
    group = group,
    buffer = bufnr,
    callback = on_diagnostic_changed,
  })

  vim.schedule(function()
    if api.nvim_buf_is_valid(bufnr) then
      local cursor = api.nvim_win_get_cursor(0)
      render_diagnostics(bufnr, cursor[1] - 1)
    end
  end)
end

function M.detach(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()
  attached_buffers = vim.tbl_filter(function(b)
    return b ~= bufnr
  end, attached_buffers)
  clear_extmarks(bufnr)
  pcall(api.nvim_del_augroup_by_name, 'PrettyInlineDiags_' .. bufnr)
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================
function M.setup(user_config)
  config = vim.tbl_deep_extend('force', DEFAULT_CONFIG, user_config or {})
  setup_sign_collapsing()

  api.nvim_create_autocmd('LspAttach', {
    group = api.nvim_create_augroup('PrettyInlineDiagsGlobal', { clear = true }),
    callback = function(args)
      M.attach(args.buf)
    end,
  })

  api.nvim_create_autocmd('DiagnosticChanged', {
    group = api.nvim_create_augroup('PrettyInlineDiagsGlobal', { clear = false }),
    callback = function(args)
      if not is_buffer_attached(args.buf) and #vim.lsp.get_clients { bufnr = args.buf } > 0 then
        M.attach(args.buf)
      end
    end,
  })
end

function M.enable()
  enabled = true
  on_cursor_moved()
end

function M.disable()
  enabled = false
  for _, bufnr in ipairs(attached_buffers) do
    clear_extmarks(bufnr)
  end
end

function M.toggle()
  if enabled then
    M.disable()
  else
    M.enable()
  end
end

function M.set_position(pos)
  if pos == 'eol' or pos == 'above' or pos == 'below' then
    config.position = pos
    on_cursor_moved()
  end
end

function M.set_preset(preset)
  if PRESETS[preset] then
    config.preset = preset
    on_cursor_moved()
  end
end

function M.cycle_preset()
  local presets = { 'modern', 'minimal', 'powerline', 'ghost' }
  local current_idx = 1
  for i, p in ipairs(presets) do
    if p == config.preset then
      current_idx = i
      break
    end
  end
  local next_idx = (current_idx % #presets) + 1
  M.set_preset(presets[next_idx])
  print('Diagnostic preset: ' .. presets[next_idx])
end

function M.cycle_position()
  local positions = { 'eol', 'below', 'above' }
  local current_idx = 1
  for i, p in ipairs(positions) do
    if p == config.position then
      current_idx = i
      break
    end
  end
  local next_idx = (current_idx % #positions) + 1
  M.set_position(positions[next_idx])
  print('Diagnostic position: ' .. positions[next_idx])
end

function M.status()
  return {
    enabled = enabled,
    attached_buffers = #attached_buffers,
    config = config,
  }
end

return M
