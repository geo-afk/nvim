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
  [vim.diagnostic.severity.ERROR] = '󰅚', -- Filled circle with X
  [vim.diagnostic.severity.WARN] = '󰀪', -- Filled triangle
  [vim.diagnostic.severity.INFO] = '󰋽', -- Filled circle with i
  [vim.diagnostic.severity.HINT] = '󰌶', -- Lightbulb
}

local SEVERITY_NAMES = {
  [vim.diagnostic.severity.ERROR] = 'Error',
  [vim.diagnostic.severity.WARN] = 'Warn',
  [vim.diagnostic.severity.INFO] = 'Info',
  [vim.diagnostic.severity.HINT] = 'Hint',
}

-- Modern color schemes with enhanced blending
local COLOR_THEMES = {
  -- Catppuccin-inspired with softer tones
  catppuccin = {
    error_fg = '#f38ba8',
    error_bg = '#3c2632',
    error_border = '#5a3a48',
    warn_fg = '#fab387',
    warn_bg = '#3a2f28',
    warn_border = '#5a4838',
    info_fg = '#89dceb',
    info_bg = '#253344',
    info_border = '#3a4a5a',
    hint_fg = '#a6e3a1',
    hint_bg = '#273833',
    hint_border = '#3a5048',
  },
  -- Tokyo Night inspired with enhanced contrast
  tokyo = {
    error_fg = '#f7768e',
    error_bg = '#3d2a33',
    error_border = '#5a3d48',
    warn_fg = '#e0af68',
    warn_bg = '#3a3329',
    warn_border = '#5a4a38',
    info_fg = '#7aa2f7',
    info_bg = '#283044',
    info_border = '#3d4a62',
    hint_fg = '#9ece6a',
    hint_bg = '#2a3733',
    hint_border = '#3d5248',
  },
  -- Nord inspired with cooler tones
  nord = {
    error_fg = '#bf616a',
    error_bg = '#3b2e32',
    error_border = '#5a4448',
    warn_fg = '#ebcb8b',
    warn_bg = '#3a3729',
    warn_border = '#5a5238',
    info_fg = '#81a1c1',
    info_bg = '#2e3440',
    info_border = '#434c5e',
    hint_fg = '#a3be8c',
    hint_bg = '#2e3d33',
    hint_border = '#435548',
  },
  -- Dracula inspired with vibrant accents
  dracula = {
    error_fg = '#ff5555',
    error_bg = '#3d2a2e',
    error_border = '#5a3d42',
    warn_fg = '#ffb86c',
    warn_bg = '#3d342a',
    warn_border = '#5a4d38',
    info_fg = '#8be9fd',
    info_bg = '#2a3d3d',
    info_border = '#3d5a5a',
    hint_fg = '#50fa7b',
    hint_bg = '#2a3d2e',
    hint_border = '#3d5a42',
  },
  -- Gruvbox inspired with warm earth tones
  gruvbox = {
    error_fg = '#fb4934',
    error_bg = '#3c2a2a',
    error_border = '#5a3d3d',
    warn_fg = '#fabd2f',
    warn_bg = '#3d3428',
    warn_border = '#5a4d38',
    info_fg = '#83a598',
    info_bg = '#2d3436',
    info_border = '#434d52',
    hint_fg = '#b8bb26',
    hint_bg = '#2d362a',
    hint_border = '#43523d',
  },
  -- New: Glassmorphism theme with transparency
  glass = {
    error_fg = '#ff6b6b',
    error_bg = '#2d1f1f',
    error_border = '#4a3535',
    warn_fg = '#ffd93d',
    warn_bg = '#2d2a1f',
    warn_border = '#4a4535',
    info_fg = '#6bcfff',
    info_bg = '#1f2a2d',
    info_border = '#35454a',
    hint_fg = '#6bff8f',
    hint_bg = '#1f2d24',
    hint_border = '#354a3d',
  },
}

local PRESETS = {
  -- Fully rounded pill design (modern standard)
  pill = {
    left = ' ',
    right = ' ',
    separator = ' 󰇘 ',
    padding = '  ',
    spacing = ' ',
  },
  -- Rounded with accent
  modern = {
    left = ' ',
    right = ' ',
    separator = ' 󰇘 ',
    padding = '  ',
    spacing = ' ',
  },
  -- Bubble style with extra padding
  bubble = {
    left = ' ',
    right = ' ',
    separator = '  ',
    padding = '   ',
    spacing = '  ',
  },
  -- Sleek minimal
  sleek = {
    left = '▏',
    right = '',
    separator = ' 󰜴 ',
    padding = ' ',
    spacing = ' ',
  },
  -- Ultra minimal
  minimal = {
    left = '',
    right = '',
    separator = ' ',
    padding = ' ',
    spacing = ' ',
  },
  -- Compact for small screens
  compact = {
    left = '',
    right = '',
    separator = '·',
    padding = ' ',
    spacing = ' ',
  },
}

-- ============================================================================
-- DEFAULT CONFIG
-- ============================================================================
local DEFAULT_CONFIG = {
  preset = 'pill',
  theme = 'catppuccin',
  use_background = true,
  use_border = true, -- Add subtle border for depth
  use_shadow = true, -- Soft shadow effect
  throttle_ms = 100,
  show_source = false,
  max_line_length = nil,
  severity_sort = true,

  -- Text wrapping configuration
  wrap = {
    enabled = true,
    max_width = 80, -- Characters before wrapping
    indent = 2, -- Spaces to indent wrapped lines
  },

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
    separator = ' 󰇘 ',
  },

  -- Blend factor for softer backgrounds (0.0 = transparent, 1.0 = solid)
  blend_factor = 0.8,
}

-- ============================================================================
-- HIGHLIGHT SETUP
-- ============================================================================
local function blend_colors(fg, bg, factor)
  -- Simple color blending helper
  if not fg or not bg then
    return fg
  end

  -- Extract RGB values
  local function hex_to_rgb(hex)
    hex = hex:gsub('#', '')
    return tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
  end

  local fr, fg_val, fb = hex_to_rgb(fg)
  local br, bg_val, bb = hex_to_rgb(bg)

  if not fr or not br then
    return fg
  end

  -- Blend
  local r = math.floor(fr * (1 - factor) + br * factor)
  local g = math.floor(fg_val * (1 - factor) + bg_val * factor)
  local b = math.floor(fb * (1 - factor) + bb * factor)

  return string.format('#%02x%02x%02x', r, g, b)
end

local function setup_highlights()
  local theme = COLOR_THEMES[config.theme] or COLOR_THEMES.catppuccin

  -- Error highlights
  api.nvim_set_hl(0, 'InlineDiagError', {
    fg = theme.error_fg,
    bg = config.use_background and theme.error_bg or 'NONE',
    bold = true,
  })

  api.nvim_set_hl(0, 'InlineDiagErrorBorder', {
    fg = theme.error_border,
  })

  -- Warn highlights
  api.nvim_set_hl(0, 'InlineDiagWarn', {
    fg = theme.warn_fg,
    bg = config.use_background and theme.warn_bg or 'NONE',
    bold = true,
  })

  api.nvim_set_hl(0, 'InlineDiagWarnBorder', {
    fg = theme.warn_border,
  })

  -- Info highlights
  api.nvim_set_hl(0, 'InlineDiagInfo', {
    fg = theme.info_fg,
    bg = config.use_background and theme.info_bg or 'NONE',
  })

  api.nvim_set_hl(0, 'InlineDiagInfoBorder', {
    fg = theme.info_border,
  })

  -- Hint highlights
  api.nvim_set_hl(0, 'InlineDiagHint', {
    fg = theme.hint_fg,
    bg = config.use_background and theme.hint_bg or 'NONE',
  })

  api.nvim_set_hl(0, 'InlineDiagHintBorder', {
    fg = theme.hint_border,
  })

  -- Icon highlights (slightly dimmed for better contrast)
  api.nvim_set_hl(0, 'InlineDiagErrorIcon', {
    fg = blend_colors(theme.error_fg, theme.error_bg, 0.3),
  })

  api.nvim_set_hl(0, 'InlineDiagWarnIcon', {
    fg = blend_colors(theme.warn_fg, theme.warn_bg, 0.3),
  })

  api.nvim_set_hl(0, 'InlineDiagInfoIcon', {
    fg = blend_colors(theme.info_fg, theme.info_bg, 0.3),
  })

  api.nvim_set_hl(0, 'InlineDiagHintIcon', {
    fg = blend_colors(theme.hint_fg, theme.hint_bg, 0.3),
  })
end

local SEVERITY_HL = {
  [vim.diagnostic.severity.ERROR] = 'InlineDiagError',
  [vim.diagnostic.severity.WARN] = 'InlineDiagWarn',
  [vim.diagnostic.severity.INFO] = 'InlineDiagInfo',
  [vim.diagnostic.severity.HINT] = 'InlineDiagHint',
}

local SEVERITY_HL_BORDER = {
  [vim.diagnostic.severity.ERROR] = 'InlineDiagErrorBorder',
  [vim.diagnostic.severity.WARN] = 'InlineDiagWarnBorder',
  [vim.diagnostic.severity.INFO] = 'InlineDiagInfoBorder',
  [vim.diagnostic.severity.HINT] = 'InlineDiagHintBorder',
}

local SEVERITY_HL_ICON = {
  [vim.diagnostic.severity.ERROR] = 'InlineDiagErrorIcon',
  [vim.diagnostic.severity.WARN] = 'InlineDiagWarnIcon',
  [vim.diagnostic.severity.INFO] = 'InlineDiagInfoIcon',
  [vim.diagnostic.severity.HINT] = 'InlineDiagHintIcon',
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

local function wrap_text(text, max_width, indent_str)
  if not config.wrap.enabled then
    return { text }
  end

  local lines = {}
  local words = {}

  -- Split into words
  for word in text:gmatch '%S+' do
    table.insert(words, word)
  end

  local current_line = ''
  local indent = string.rep(' ', indent_str or 0)

  for i, word in ipairs(words) do
    local test_line = current_line == '' and word or (current_line .. ' ' .. word)

    if #test_line > max_width and current_line ~= '' then
      table.insert(lines, current_line)
      current_line = indent .. word
    else
      current_line = test_line
    end
  end

  if current_line ~= '' then
    table.insert(lines, current_line)
  end

  return lines
end

local function format_diagnostic_message(diag, include_icon)
  local icon = include_icon and SEVERITY_ICONS[diag.severity] or ''
  local msg = diag.message or ''

  -- Clean up message (remove newlines, extra spaces)
  msg = msg:gsub('\n', ' '):gsub('%s+', ' ')

  if config.show_source and diag.source then
    msg = string.format('%s 󰅩 %s', msg, diag.source)
  end

  local max_len = config.max_line_length or (vim.o.columns - 20)
  if #msg > max_len and not config.wrap.enabled then
    msg = msg:sub(1, max_len - 3) .. '…'
  end

  return icon, msg
end

local function format_diagnostics(diags)
  if #diags == 0 then
    return nil
  end

  local style = PRESETS[config.preset] or PRESETS.pill
  local virt_text = {}

  if not config.multiline.enabled then
    local diag = diags[1]
    local icon, msg = format_diagnostic_message(diag, true)
    local hl = SEVERITY_HL[diag.severity]
    local icon_hl = SEVERITY_HL_ICON[diag.severity]
    local border_hl = SEVERITY_HL_BORDER[diag.severity]

    -- Add leading padding
    table.insert(virt_text, { style.padding, 'Normal' })

    -- Add subtle border start (optional)
    if config.use_border then
      table.insert(virt_text, { '▏', border_hl })
    end

    -- Add opening with shadow effect
    if config.use_shadow then
      table.insert(virt_text, { style.left, border_hl })
    else
      table.insert(virt_text, { style.left, hl })
    end

    -- Add icon with separate highlight
    table.insert(virt_text, { icon .. style.spacing, icon_hl })

    -- Handle text wrapping
    if config.wrap.enabled then
      local wrapped_lines = wrap_text(msg, config.wrap.max_width, config.wrap.indent)

      for i, line in ipairs(wrapped_lines) do
        if i == 1 then
          table.insert(virt_text, { line, hl })
        else
          -- For continuation lines, add as separate extmark
          -- This would need to be handled in the rendering function
        end
      end
    else
      table.insert(virt_text, { msg, hl })
    end

    -- Add closing
    if config.use_shadow then
      table.insert(virt_text, { style.right, border_hl })
    else
      table.insert(virt_text, { style.right, hl })
    end

    -- Add subtle border end (optional)
    if config.use_border then
      table.insert(virt_text, { '▕', border_hl })
    end

    -- Add count badge if multiple diagnostics
    if #diags > 1 then
      local badge = string.format(' 󰔵 +%d ', #diags - 1)
      table.insert(virt_text, { badge, 'Comment' })
    end
  else
    -- Multiline diagnostics
    local messages = {}
    local max_lines = math.min(#diags, config.multiline.max_lines)
    local primary_severity = diags[1].severity

    for i = 1, max_lines do
      local icon, msg = format_diagnostic_message(diags[i], true)
      table.insert(messages, icon .. style.spacing .. msg)
    end

    if #diags > max_lines then
      table.insert(messages, string.format('󰇘 +%d more…', #diags - max_lines))
    end

    local combined = table.concat(messages, config.multiline.separator)
    local hl = SEVERITY_HL[primary_severity]
    local border_hl = SEVERITY_HL_BORDER[primary_severity]

    table.insert(virt_text, { style.padding, 'Normal' })

    if config.use_border then
      table.insert(virt_text, { '▏', border_hl })
    end

    table.insert(virt_text, { style.left, border_hl })
    table.insert(virt_text, { combined, hl })
    table.insert(virt_text, { style.right, border_hl })

    if config.use_border then
      table.insert(virt_text, { '▕', border_hl })
    end
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

  -- Handle wrapped text continuation (if enabled)
  if config.wrap.enabled then
    local diag = diags[1]
    local _, msg = format_diagnostic_message(diag, false)
    local wrapped_lines = wrap_text(msg, config.wrap.max_width, config.wrap.indent)

    -- Render continuation lines
    for i = 2, #wrapped_lines do
      local continuation_text = {
        { string.rep(' ', config.wrap.indent + 2), 'Normal' },
        { wrapped_lines[i], SEVERITY_HL[diag.severity] },
      }

      pcall(api.nvim_buf_set_extmark, bufnr, ns_id, line_0based, 0, {
        virt_lines = { continuation_text },
        virt_lines_above = false,
        hl_mode = 'combine',
        priority = 999,
      })
    end
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
  setup_highlights()
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

-- Toggle wrapping
function M.toggle_wrap()
  config.wrap.enabled = not config.wrap.enabled
  on_cursor_moved()
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
