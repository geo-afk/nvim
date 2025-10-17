local M = {}

-- ============================================================================
-- STATE
-- ============================================================================
local api = vim.api
local ns_id = api.nvim_create_namespace 'custom_inline_diagnostics'
local enabled = true
local config = {}
local attached_buffers = {}
local autocmd_ids = {}
local debounce_timer = nil

-- ============================================================================
-- MODERN ICONS & STYLING
-- ============================================================================
local SEVERITY_ICONS = {
  [vim.diagnostic.severity.ERROR] = '󰅚 ', -- Filled circle with X
  [vim.diagnostic.severity.WARN] = '󰀪 ', -- Filled triangle
  [vim.diagnostic.severity.INFO] = '󰋽 ', -- Filled circle with i
  [vim.diagnostic.severity.HINT] = '󰌶 ', -- Lightbulb
}

local SEVERITY_NAMES = {
  [vim.diagnostic.severity.ERROR] = 'Error',
  [vim.diagnostic.severity.WARN] = 'Warn',
  [vim.diagnostic.severity.INFO] = 'Info',
  [vim.diagnostic.severity.HINT] = 'Hint',
}

-- Modern color schemes
local COLOR_THEMES = {
  -- Catppuccin-inspired
  catppuccin = {
    error_fg = '#f38ba8',
    error_bg = '#3c2632',
    warn_fg = '#fab387',
    warn_bg = '#3a2f28',
    info_fg = '#89dceb',
    info_bg = '#253344',
    hint_fg = '#a6e3a1',
    hint_bg = '#273833',
  },
  -- Tokyo Night inspired
  tokyo = {
    error_fg = '#f7768e',
    error_bg = '#3d2a33',
    warn_fg = '#e0af68',
    warn_bg = '#3a3329',
    info_fg = '#7aa2f7',
    info_bg = '#283044',
    hint_fg = '#9ece6a',
    hint_bg = '#2a3733',
  },
  -- Nord inspired
  nord = {
    error_fg = '#bf616a',
    error_bg = '#3b2e32',
    warn_fg = '#ebcb8b',
    warn_bg = '#3a3729',
    info_fg = '#81a1c1',
    info_bg = '#2e3440',
    hint_fg = '#a3be8c',
    hint_bg = '#2e3d33',
  },
  -- Dracula inspired
  dracula = {
    error_fg = '#ff5555',
    error_bg = '#3d2a2e',
    warn_fg = '#ffb86c',
    warn_bg = '#3d342a',
    info_fg = '#8be9fd',
    info_bg = '#2a3d3d',
    hint_fg = '#50fa7b',
    hint_bg = '#2a3d2e',
  },
  -- Gruvbox inspired
  gruvbox = {
    error_fg = '#fb4934',
    error_bg = '#3c2a2a',
    warn_fg = '#fabd2f',
    warn_bg = '#3d3428',
    info_fg = '#83a598',
    info_bg = '#2d3436',
    hint_fg = '#b8bb26',
    hint_bg = '#2d362a',
  },
}

local PRESETS = {
  modern = {
    left = '  ',
    right = ' ',
    arrow = ' 󰁔 ', -- Rounded arrow
    padding = '  ',
  },
  bubble = {
    left = ' ',
    right = ' ',
    arrow = '  ',
    padding = '  ',
  },
  sleek = {
    left = ' ▏',
    right = '',
    arrow = ' 󰜴 ', -- Sleek arrow
    padding = ' ',
  },
  minimal = {
    left = '',
    right = '',
    arrow = ' ',
    padding = ' ',
  },
}

-- ============================================================================
-- DEFAULT CONFIG
-- ============================================================================
local DEFAULT_CONFIG = {
  preset = 'modern',
  theme = 'catppuccin', -- Color theme
  use_background = true, -- Show colored background
  use_border = false, -- Add border effect
  throttle_ms = 100,
  show_source = false,
  max_line_length = nil,
  severity_sort = true,

  -- Which severities to show
  severities = {
    [vim.diagnostic.severity.ERROR] = true,
    [vim.diagnostic.severity.WARN] = true,
    [vim.diagnostic.severity.INFO] = true,
    [vim.diagnostic.severity.HINT] = true,
  },

  disabled_filetypes = {},

  multiline = {
    enabled = false,
    max_lines = 3,
    separator = ' 󰇘 ', -- Diamond separator
  },
}

-- ============================================================================
-- HIGHLIGHT SETUP
-- ============================================================================
local function setup_highlights()
  local theme = COLOR_THEMES[config.theme] or COLOR_THEMES.catppuccin

  -- Error highlights
  api.nvim_set_hl(0, 'InlineDiagError', {
    fg = theme.error_fg,
    bg = config.use_background and theme.error_bg or 'NONE',
    bold = true,
  })

  -- Warn highlights
  api.nvim_set_hl(0, 'InlineDiagWarn', {
    fg = theme.warn_fg,
    bg = config.use_background and theme.warn_bg or 'NONE',
    bold = true,
  })

  -- Info highlights
  api.nvim_set_hl(0, 'InlineDiagInfo', {
    fg = theme.info_fg,
    bg = config.use_background and theme.info_bg or 'NONE',
  })

  -- Hint highlights
  api.nvim_set_hl(0, 'InlineDiagHint', {
    fg = theme.hint_fg,
    bg = config.use_background and theme.hint_bg or 'NONE',
  })
end

local SEVERITY_HL = {
  [vim.diagnostic.severity.ERROR] = 'InlineDiagError',
  [vim.diagnostic.severity.WARN] = 'InlineDiagWarn',
  [vim.diagnostic.severity.INFO] = 'InlineDiagInfo',
  [vim.diagnostic.severity.HINT] = 'InlineDiagHint',
}

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

local function is_buffer_attached(bufnr)
  return vim.api.nvim_buf_is_valid(bufnr) and vim.tbl_contains(attached_buffers, bufnr)
end

local function get_diagnostics_for_line(bufnr, line_0based)
  if not api.nvim_buf_is_valid(bufnr) then
    return {}
  end

  local all_diags = vim.diagnostic.get(bufnr, { lnum = line_0based })

  local filtered = vim.tbl_filter(function(diag)
    return config.severities[diag.severity] == true
  end, all_diags)

  if config.severity_sort then
    table.sort(filtered, function(a, b)
      return a.severity < b.severity
    end)
  end

  return filtered
end

local function format_diagnostic_message(diag)
  local icon = SEVERITY_ICONS[diag.severity] or ''
  local msg = diag.message or ''

  -- Clean up message (remove newlines, extra spaces)
  msg = msg:gsub('\n', ' '):gsub('%s+', ' ')

  if config.show_source and diag.source then
    msg = string.format('%s 󰅩 %s', msg, diag.source)
  end

  local max_len = config.max_line_length or (vim.o.columns - 15)
  if #msg > max_len then
    msg = msg:sub(1, max_len - 3) .. '…'
  end

  return icon .. msg
end

local function format_diagnostics(diags)
  if #diags == 0 then
    return nil
  end

  local style = PRESETS[config.preset] or PRESETS.modern
  local virt_text = {}

  if not config.multiline.enabled then
    local diag = diags[1]
    local msg = format_diagnostic_message(diag)
    local formatted = style.padding .. style.left .. msg .. style.right
    local hl = SEVERITY_HL[diag.severity]

    table.insert(virt_text, { formatted, hl })

    -- Add count badge if multiple diagnostics
    if #diags > 1 then
      local badge = string.format(' +%d ', #diags - 1)
      table.insert(virt_text, { badge, 'Comment' })
    end
  else
    local messages = {}
    local max_lines = math.min(#diags, config.multiline.max_lines)

    for i = 1, max_lines do
      local msg = format_diagnostic_message(diags[i])
      table.insert(messages, msg)
    end

    if #diags > max_lines then
      table.insert(messages, string.format('󰇘 %d more…', #diags - max_lines))
    end

    local combined = table.concat(messages, config.multiline.separator)
    local formatted = style.padding .. style.left .. combined .. style.right
    local hl = SEVERITY_HL[diags[1].severity]
    table.insert(virt_text, { formatted, hl })
  end

  return virt_text
end

-- ============================================================================
-- CORE RENDERING
-- ============================================================================

local function clear_virtual_text(bufnr)
  if not api.nvim_buf_is_valid(bufnr) then
    return
  end
  api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
end

local function render_diagnostics(bufnr, line_0based)
  if not enabled then
    return
  end

  if not api.nvim_buf_is_valid(bufnr) then
    return
  end

  clear_virtual_text(bufnr)

  local diags = get_diagnostics_for_line(bufnr, line_0based)
  if #diags == 0 then
    return
  end

  local virt_text = format_diagnostics(diags)
  if not virt_text then
    return
  end

  local ok = pcall(api.nvim_buf_set_extmark, bufnr, ns_id, line_0based, 0, {
    virt_text = virt_text,
    virt_text_pos = 'eol',
    hl_mode = 'combine',
    priority = 1000,
  })

  if not ok then
    return
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
    local line_1based = cursor[1]
    local line_0based = line_1based - 1

    render_diagnostics(bufnr, line_0based)
  end, config.throttle_ms)
end

local function on_diagnostic_changed(args)
  local bufnr = args.buf
  if not is_buffer_attached(bufnr) then
    return
  end

  local cursor = api.nvim_win_get_cursor(0)
  local line_0based = cursor[1] - 1
  render_diagnostics(bufnr, line_0based)
end

-- ============================================================================
-- BUFFER ATTACHMENT
-- ============================================================================

function M.attach(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()

  if not api.nvim_buf_is_valid(bufnr) then
    return
  end

  if is_buffer_attached(bufnr) then
    return
  end

  local ft = vim.bo[bufnr].filetype
  if vim.tbl_contains(config.disabled_filetypes, ft) then
    return
  end

  table.insert(attached_buffers, bufnr)
  autocmd_ids[bufnr] = {}

  local group = api.nvim_create_augroup('CustomInlineDiag_' .. bufnr, { clear = true })

  autocmd_ids[bufnr].cursor_moved = api.nvim_create_autocmd('CursorMoved', {
    group = group,
    buffer = bufnr,
    callback = on_cursor_moved,
  })

  autocmd_ids[bufnr].cursor_moved_i = api.nvim_create_autocmd('CursorMovedI', {
    group = group,
    buffer = bufnr,
    callback = on_cursor_moved,
  })

  autocmd_ids[bufnr].diagnostic_changed = api.nvim_create_autocmd('DiagnosticChanged', {
    group = group,
    buffer = bufnr,
    callback = on_diagnostic_changed,
  })

  vim.schedule(function()
    if api.nvim_buf_is_valid(bufnr) then
      local cursor = api.nvim_win_get_cursor(0)
      local line_0based = cursor[1] - 1
      render_diagnostics(bufnr, line_0based)
    end
  end)
end

function M.detach(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()

  attached_buffers = vim.tbl_filter(function(b)
    return b ~= bufnr
  end, attached_buffers)

  clear_virtual_text(bufnr)

  if autocmd_ids[bufnr] then
    local group = 'CustomInlineDiag_' .. bufnr
    pcall(api.nvim_del_augroup_by_name, group)
    autocmd_ids[bufnr] = nil
  end
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

function M.setup(user_config)
  config = vim.tbl_deep_extend('force', DEFAULT_CONFIG, user_config or {})

  -- Setup custom highlights
  setup_highlights()

  -- Re-setup highlights on colorscheme change
  api.nvim_create_autocmd('ColorScheme', {
    group = api.nvim_create_augroup('CustomInlineDiagColors', { clear = true }),
    callback = setup_highlights,
  })

  -- Auto-attach on LSP attach
  api.nvim_create_autocmd('LspAttach', {
    group = api.nvim_create_augroup('CustomInlineDiagSetup', { clear = true }),
    callback = function(args)
      M.attach(args.buf)
    end,
  })

  -- Also try to attach to existing buffers with diagnostics
  api.nvim_create_autocmd('DiagnosticChanged', {
    group = api.nvim_create_augroup('CustomInlineDiagSetup', { clear = false }),
    callback = function(args)
      if not is_buffer_attached(args.buf) then
        local clients = vim.lsp.get_clients { bufnr = args.buf }
        if #clients > 0 then
          M.attach(args.buf)
        end
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
    clear_virtual_text(bufnr)
  end
end

function M.toggle()
  if enabled then
    M.disable()
  else
    M.enable()
  end
end

function M.update_config(new_config)
  config = vim.tbl_deep_extend('force', config, new_config)
  setup_highlights() -- Refresh highlights
  on_cursor_moved()
end

-- Change theme on the fly
function M.set_theme(theme_name)
  if COLOR_THEMES[theme_name] then
    config.theme = theme_name
    setup_highlights()
    on_cursor_moved()
  end
end

-- Change preset on the fly
function M.set_preset(preset_name)
  if PRESETS[preset_name] then
    config.preset = preset_name
    on_cursor_moved()
  end
end

function M.status()
  return {
    enabled = enabled,
    attached_buffers = attached_buffers,
    config = config,
    available_themes = vim.tbl_keys(COLOR_THEMES),
    available_presets = vim.tbl_keys(PRESETS),
  }
end

return M
