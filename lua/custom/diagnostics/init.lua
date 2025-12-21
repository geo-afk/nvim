local M = {}

-- ============================================================================
-- Collapse multiple diagnostic signs into one sign per severity on each line
-- E.g. EEEEEWWWHH → EWH
-- Source: https://neovim.io/doc/user/diagnostic.html#diagnostic-handlers-example
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
-- ICONS & SEVERITY NAMES
-- ============================================================================
local SEVERITY_ICONS = {
  [vim.diagnostic.severity.ERROR] = ' ',
  [vim.diagnostic.severity.WARN] = ' ',
  [vim.diagnostic.severity.INFO] = ' ',
  [vim.diagnostic.severity.HINT] = ' ',
}

local SEVERITY_NAMES = {
  [vim.diagnostic.severity.ERROR] = 'Error',
  [vim.diagnostic.severity.WARN] = 'Warning',
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
  -- Display position: 'eol' for end-of-line (like tiny-inline-diagnostic), 'above' for virtual lines above (like lsp_lines)
  position = 'eol', -- 'eol' | 'above'

  -- For eol position
  preset = 'modern', -- modern, minimal, icons_only
  show_source = true,
  show_count = true,
  multiline = true, -- Show multiple diagnostics if present

  -- NEW: Prevent overly long messages from overflowing the screen
  eol_max_width = 80, -- Maximum characters for eol messages (false/nil to disable truncation)

  -- For above position
  show_code_snippet = true,
  max_diagnostics = 5,

  throttle_ms = 100,
  severity_sort = true,

  severities = {
    [vim.diagnostic.severity.ERROR] = true,
    [vim.diagnostic.severity.WARN] = true,
    [vim.diagnostic.severity.INFO] = true,
    [vim.diagnostic.severity.HINT] = true,
  },

  disabled_filetypes = {},
}

-- Simple presets for eol styling
local PRESETS = {
  modern = { left = ' ▏', right = '▕ ', separator = ' │ ' },
  minimal = { left = '', right = '', separator = ' • ' },
  icons_only = { left = ' ', right = '', separator = ' ' },
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

local function truncate_text(text, max_width)
  if not max_width or max_width <= 0 then
    return text
  end
  if #text > max_width then
    return text:sub(1, max_width - 1) .. '…'
  end
  return text
end

local function format_message(diag)
  local icon = SEVERITY_ICONS[diag.severity] or ''
  local severity = config.show_source and SEVERITY_NAMES[diag.severity] or ''
  local source = config.show_source and diag.source and (' [' .. diag.source .. ']') or ''
  local msg = diag.message:gsub('\n', ' '):gsub('%s+', ' ')

  local full_text = icon .. ' ' .. (severity ~= '' and severity .. ': ' or '') .. msg .. source

  -- Apply truncation only for eol position
  if config.position == 'eol' and config.eol_max_width then
    full_text = truncate_text(full_text, config.eol_max_width)
  end

  return full_text, SEVERITY_HL[diag.severity]
end

local function get_line_text(bufnr, line_0based)
  return api.nvim_buf_get_lines(bufnr, line_0based, line_0based + 1, false)[1] or ''
end

-- ============================================================================
-- RENDERING
-- ============================================================================
local function clear_extmarks(bufnr)
  if api.nvim_buf_is_valid(bufnr) then
    pcall(api.nvim_buf_clear_namespace, bufnr, ns_id, 0, -1)
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

  local style = PRESETS[config.preset] or PRESETS.modern

  if config.position == 'eol' then
    local virt_text = {}

    if not config.multiline then
      local primary = diags[1]
      local text, hl = format_message(primary)
      table.insert(virt_text, { style.left, hl })
      table.insert(virt_text, { text, hl })
      table.insert(virt_text, { style.right, hl })

      if config.show_count and #diags > 1 then
        table.insert(virt_text, { ' +' .. (#diags - 1), 'Comment' })
      end
    else
      for i, diag in ipairs(diags) do
        local text, hl = format_message(diag)
        if i > 1 then
          table.insert(virt_text, { style.separator, 'Comment' })
        end
        table.insert(virt_text, { text, hl })
      end
    end

    pcall(api.nvim_buf_set_extmark, bufnr, ns_id, line_0based, -1, {
      virt_text = virt_text,
      virt_text_pos = 'eol',
      hl_mode = 'combine',
      priority = 1000,
    })
  else -- 'above' virtual lines
    local virt_lines = {}
    local max = math.min(#diags, config.max_diagnostics)

    for i = 1, max do
      local diag = diags[i]
      local text, hl = format_message(diag)
      local line = {}
      if config.show_code_snippet then
        local code = get_line_text(bufnr, line_0based)
        table.insert(line, { code, 'Normal' })
        table.insert(line, { ' ► ', 'Comment' })
      end
      table.insert(line, { text, hl })
      table.insert(virt_lines, line)
    end

    if #diags > max then
      table.insert(virt_lines, { { '… ' .. (#diags - max) .. ' more diagnostics', 'Comment' } })
    end

    pcall(api.nvim_buf_set_extmark, bufnr, ns_id, line_0based, 0, {
      virt_lines = virt_lines,
      virt_lines_above = true,
      hl_mode = 'combine',
      priority = 1000,
    })
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

  -- Setup sign collapsing once when the plugin is configured
  setup_sign_collapsing()

  -- Auto-attach on LSP
  api.nvim_create_autocmd('LspAttach', {
    group = api.nvim_create_augroup('PrettyInlineDiagsGlobal', { clear = true }),
    callback = function(args)
      M.attach(args.buf)
    end,
  })

  -- Attach if diagnostics appear and LSP is attached
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
  if pos == 'eol' or pos == 'above' then
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

function M.status()
  return {
    enabled = enabled,
    attached_buffers = #attached_buffers,
    config = config,
  }
end

return M
