local M = {}

-- Module configuration (user-overridable)
M.config = {
  border_style = 'rounded',
  highlight_duration = 2000,
  popup_width_factor = 0.7,
  popup_height_factor = 0.3,
  use_snacks = true, -- Attempt to use snacks.nvim if available
}

function M.setup(user_config)
  M.config = vim.tbl_deep_extend('force', M.config, user_config or {})
end

-- Helper function to format path for display
local function format_path_for_title(filepath, max_length)
  max_length = max_length or 50
  local cwd = vim.fn.getcwd()
  local full_path = vim.fn.fnamemodify(filepath, ':p')
  local display_path
  if vim.startswith(full_path, cwd) then
    display_path = vim.fn.fnamemodify(full_path, ':.')
  else
    display_path = vim.fn.fnamemodify(full_path, ':~')
  end
  if #display_path > max_length then
    display_path = vim.fn.pathshorten(display_path)
  end
  return display_path
end

-- Calculate dynamic z-index for proper stacking
local function calculate_zindex()
  local base_zindex = 1000
  local current_zindex = base_zindex
  for _, win_id in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win_id) then
      local win_config = vim.api.nvim_win_get_config(win_id)
      if win_config.relative ~= '' and win_config.zindex and win_config.zindex >= current_zindex then
        current_zindex = win_config.zindex + 10
      end
    end
  end
  return current_zindex
end

-- Create and configure popup window with dynamic sizing
local function create_popup_window(bufnr, title, custom_opts)
  custom_opts = custom_opts or {}
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local max_width = math.min(80, math.floor(vim.o.columns * 0.8))
  local content_width = math.max(20, math.min(max_width, math.max(unpack(vim.tbl_map(string.len, lines)))))
  local content_height = math.min(20, #lines + 2) -- +2 for padding
  local default_opts = {
    style = 'minimal',
    relative = 'cursor',
    width = content_width,
    height = content_height,
    row = 1,
    col = 0,
    border = M.config.border_style,
    title = title,
    title_pos = 'center',
    zindex = calculate_zindex(),
    focusable = false,
    noautocmd = true,
  }
  local opts = vim.tbl_deep_extend('force', default_opts, custom_opts)
  local win = vim.api.nvim_open_win(bufnr, false, opts)
  vim.api.nvim_set_option_value('winblend', 10, { win = win }) -- Light transparency
  vim.api.nvim_set_option_value('scrolloff', 0, { win = win })
  vim.api.nvim_set_option_value('wrap', false, { win = win })
  return win
end

-- Add highlighting to line with configurable duration
local function add_line_highlight(bufnr, line, duration, namespace_suffix)
  duration = duration or M.config.highlight_duration
  namespace_suffix = namespace_suffix or 'highlight'
  local ns_id = vim.api.nvim_create_namespace('peek_' .. namespace_suffix)
  local line_content = vim.api.nvim_buf_get_lines(bufnr, line - 1, line, false)[1] or ''
  local line_length = #line_content
  vim.api.nvim_buf_set_extmark(bufnr, ns_id, line - 1, 0, {
    end_row = line - 1,
    end_col = line_length > 0 and line_length or 1,
    hl_group = 'Visual',
    priority = 200,
  })
  if duration > 0 then
    vim.defer_fn(function()
      if vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
      end
    end, duration)
  end
  return ns_id
end

-- Clear highlight namespace
local function clear_line_highlight(bufnr, namespace_suffix)
  if vim.api.nvim_buf_is_valid(bufnr) then
    local ns_id = vim.api.nvim_create_namespace('peek_' .. namespace_suffix)
    vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
  end
end

-- Create popup close function with optional cleanup
local function create_close_function(win, bufnr, ns_id, cleanup_fn)
  return function()
    if cleanup_fn then
      cleanup_fn()
    end
    if vim.api.nvim_win_is_valid(win) then
      if ns_id and vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
      end
      vim.api.nvim_win_close(win, true)
    end
  end
end

-- Set up popup autocmds with augroup
local function setup_popup_autocmds(win, original_buf, original_win, close_popup)
  local augroup = vim.api.nvim_create_augroup('PeekPopup', { clear = true })
  local close_autocmd = vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
    group = augroup,
    buffer = original_buf,
    callback = function()
      local current_buf = vim.api.nvim_get_current_buf()
      local current_win = vim.api.nvim_get_current_win()
      if current_buf == original_buf and current_win == original_win then
        close_popup()
        return true
      end
    end,
  })
  vim.api.nvim_create_autocmd('BufLeave', {
    group = augroup,
    buffer = original_buf,
    once = true,
    callback = function()
      vim.defer_fn(function()
        local current_win = vim.api.nvim_get_current_win()
        if current_win ~= win then
          close_popup()
        end
      end, 50)
    end,
  })
  vim.api.nvim_create_autocmd('WinClosed', {
    group = augroup,
    pattern = tostring(win),
    once = true,
    callback = function()
      if close_autocmd then
        vim.api.nvim_del_autocmd(close_autocmd)
      end
      vim.api.nvim_clear_autocmds { group = augroup }
    end,
  })
end

-- Generic peek function that works with any LSP method, handling multiple results
local function peek_lsp_result(lsp_method, title_prefix, no_result_msg)
  local clients = vim.lsp.get_clients { bufnr = 0 }
  if #clients == 0 then
    print 'No LSP client attached'
    return
  end
  local params = vim.lsp.util.make_position_params(0, clients[1].offset_encoding)
  vim.lsp.buf_request(0, lsp_method, params, function(err, result)
    if err or not result or vim.tbl_isempty(result) then
      print(no_result_msg)
      return
    end
    if not vim.islist(result) then
      result = { result }
    end
    local original_buf = vim.api.nvim_get_current_buf()
    local original_win = vim.api.nvim_get_current_win()
    if #result > 1 then
      -- Handle multiple results with a selectable list
      local bufnr = vim.api.nvim_create_buf(false, true)
      local lines = {}
      local locations = {}
      for i, location in ipairs(result) do
        local uri = location.uri or location.targetUri
        local filepath = vim.uri_to_fname(uri)
        local formatted_path = format_path_for_title(filepath)
        table.insert(lines, string.format('%d: %s', i, formatted_path))
        table.insert(locations, location)
      end
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      vim.api.nvim_set_option_value('buftype', 'nofile', { buf = bufnr })
      vim.api.nvim_set_option_value('modifiable', false, { buf = bufnr })
      local title = ' Multiple ' .. title_prefix .. 's '
      local win = create_popup_window(bufnr, title)
      local close_popup = create_close_function(win, bufnr)
      setup_popup_autocmds(win, original_buf, original_win, close_popup)
      vim.keymap.set('n', '<CR>', function()
        local cursor = vim.api.nvim_win_get_cursor(win)
        local idx = cursor[1]
        local selected = locations[idx]
        if selected then
          local range = selected.range or selected.targetSelectionRange or selected.targetRange
          vim.api.nvim_win_set_cursor(original_win, { range.start.line + 1, range.start.character })
          vim.lsp.buf.jump_to_location(selected)
        end
        close_popup()
      end, { buffer = bufnr, silent = true })
      vim.keymap.set('n', '<Esc>', close_popup, { buffer = bufnr, silent = true })
    else
      -- Single result
      local location = result[1]
      local uri = location.uri or location.targetUri
      local range = location.range or location.targetSelectionRange or location.targetRange
      local bufnr = vim.uri_to_bufnr(uri)
      vim.fn.bufload(bufnr)
      local filepath = vim.uri_to_fname(uri)
      local formatted_path = format_path_for_title(filepath)
      local title = ' ' .. title_prefix .. ' @' .. formatted_path .. ' '
      local win = create_popup_window(bufnr, title)
      local line = range.start.line + 1
      local col = range.start.character
      vim.api.nvim_win_set_cursor(win, { line, col })
      vim.api.nvim_win_call(win, function()
        vim.fn.winrestview { topline = line, lnum = line, col = col }
      end)
      local ns_id = add_line_highlight(bufnr, line, M.config.highlight_duration, 'definition_highlight')
      local close_popup = create_close_function(win, bufnr, ns_id)
      setup_popup_autocmds(win, original_buf, original_win, close_popup)
      vim.keymap.set('n', '<CR>', function()
        if vim.api.nvim_win_is_valid(original_win) then
          vim.api.nvim_set_current_win(original_win)
          vim.api.nvim_win_set_cursor(original_win, { line, col })
        end
        close_popup()
      end, { buffer = bufnr, silent = true })
      vim.keymap.set('n', '<Esc>', close_popup, { buffer = bufnr, silent = true })
    end
  end)
end

-- Create a basic popup buffer with common settings
local function create_popup_buffer(initial_lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  if initial_lines then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, initial_lines)
  end
  vim.api.nvim_set_option_value('buftype', 'nofile', { buf = bufnr })
  vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = bufnr })
  vim.api.nvim_set_option_value('swapfile', false, { buf = bufnr })
  vim.api.nvim_set_option_value('modified', false, { buf = bufnr })
  return bufnr
end

-- Create diagnostics popup buffer with formatted content
local function create_diagnostics_buffer()
  local diagnostics = vim.diagnostic.get(0)
  if #diagnostics == 0 then
    return nil, 'No diagnostics found'
  end
  local bufnr = create_popup_buffer()
  local lines = {}
  local diagnostic_data = {}
  for _, diagnostic in ipairs(diagnostics) do
    local severity = vim.diagnostic.severity[diagnostic.severity]
    local line_num = diagnostic.lnum + 1
    local col_num = diagnostic.col + 1
    local message = diagnostic.message:gsub('\n', ' ')
    local formatted_line = string.format('[%s] Line %d:%d - %s', severity, line_num, col_num, message)
    table.insert(lines, formatted_line)
    table.insert(diagnostic_data, diagnostic)
  end
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value('modifiable', false, { buf = bufnr })
  vim.api.nvim_set_option_value('filetype', 'diagnostics', { buf = bufnr })
  return bufnr, nil, diagnostic_data
end

-- Generic navigation setup for popup items (diagnostics, symbols, etc.)
local function setup_popup_navigation(popup_win, bufnr, item_data, original_win, get_position_fn, namespace_suffix)
  namespace_suffix = namespace_suffix or 'popup_highlight'
  local current_highlighted_line = nil
  local original_bufnr = vim.api.nvim_win_get_buf(original_win)
  vim.api.nvim_create_autocmd('CursorMoved', {
    buffer = bufnr,
    callback = function()
      local cursor = vim.api.nvim_win_get_cursor(0)
      local line_idx = cursor[1]
      if item_data[line_idx] and vim.api.nvim_win_is_valid(original_win) then
        local item = item_data[line_idx]
        local line, col = get_position_fn(item)
        if current_highlighted_line ~= line then
          if current_highlighted_line then
            clear_line_highlight(original_bufnr, namespace_suffix)
          end
          local scrolloff = vim.api.nvim_get_option_value('scrolloff', { win = original_win })
          local offset = math.max(5, scrolloff)
          local topline = math.max(1, line - offset)
          vim.api.nvim_win_set_cursor(original_win, { line, col })
          vim.api.nvim_win_call(original_win, function()
            vim.fn.winrestview { topline = topline, lnum = line, col = col }
          end)
          add_line_highlight(original_bufnr, line, 0, namespace_suffix)
          current_highlighted_line = line
        end
      end
    end,
  })
  vim.keymap.set('n', '<CR>', function()
    if not item_data then
      print 'No data available'
      return
    end
    local cursor = vim.api.nvim_win_get_cursor(popup_win)
    local line_idx = cursor[1]
    if item_data[line_idx] then
      local item = item_data[line_idx]
      local line, col = get_position_fn(item)
      clear_line_highlight(original_bufnr, namespace_suffix)
      vim.api.nvim_win_close(popup_win, true)
      if vim.api.nvim_win_is_valid(original_win) then
        vim.api.nvim_set_current_win(original_win)
        vim.api.nvim_win_set_cursor(original_win, { line, col })
      end
    end
  end, { buffer = bufnr, desc = 'Jump to item' })
end

-- Create symbols buffer with aligned formatting and sorting
local function create_symbols_buffer(symbols)
  -- Sort by line number
  table.sort(symbols, function(a, b)
    return a.location.range.start.line < b.location.range.start.line
  end)
  local bufnr = create_popup_buffer()
  local lines = {}
  local symbol_data = {}
  local max_line_num = 0
  for _, symbol in ipairs(symbols) do
    local line_num = symbol.location.range.start.line + 1
    if line_num > max_line_num then
      max_line_num = line_num
    end
  end
  local line_width = string.len(tostring(max_line_num))
  for i, symbol in ipairs(symbols) do
    local kind_name = vim.lsp.protocol.SymbolKind[symbol.kind] or 'Unknown'
    local line_num = symbol.location.range.start.line + 1
    local line_text = string.format('%' .. line_width .. 'd: %s %s', line_num, kind_name, symbol.name)
    if symbol.containerName then
      line_text = line_text .. ' (' .. symbol.containerName .. ')'
    end
    table.insert(lines, line_text)
    symbol_data[i] = {
      lnum = symbol.location.range.start.line,
      col = symbol.location.range.start.character,
      message = line_text,
      original_symbol = symbol,
    }
  end
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value('modifiable', false, { buf = bufnr })
  return bufnr, nil, symbol_data
end

-- Create bottom-right popup window
local function create_bottom_right_popup(bufnr, title, original_win, width_factor, height_factor)
  width_factor = width_factor or M.config.popup_width_factor
  height_factor = height_factor or M.config.popup_height_factor
  local win_height = vim.api.nvim_win_get_height(original_win)
  local win_width = vim.api.nvim_win_get_width(original_win)
  local popup_width = math.min(80, math.floor(win_width * width_factor))
  local popup_height = math.min(20, math.floor(win_height * height_factor))
  return create_popup_window(bufnr, title, {
    relative = 'win',
    win = original_win,
    width = popup_width,
    height = popup_height,
    row = win_height - popup_height - 2,
    col = win_width - popup_width - 1,
  })
end

-- Common popup setup with navigation
local function setup_peek_popup(popup_bufnr, popup_win, original_win, item_data, namespace_suffix)
  local ns_id = vim.api.nvim_create_namespace('peek_' .. namespace_suffix)
  local cleanup_fn = function()
    clear_line_highlight(vim.api.nvim_win_get_buf(original_win), namespace_suffix)
  end
  local close_with_cleanup = create_close_function(popup_win, popup_bufnr, ns_id, cleanup_fn)
  setup_popup_autocmds(popup_win, vim.api.nvim_get_current_buf(), original_win, close_with_cleanup)
  local get_position = function(item)
    return item.lnum + 1, item.col
  end
  setup_popup_navigation(popup_win, popup_bufnr, item_data, original_win, get_position, namespace_suffix)
  vim.keymap.set('n', '<Esc>', close_with_cleanup, { buffer = popup_bufnr, silent = true })
end

-- Create symbol kind lookup for filtering
local function create_symbol_kind_map(symbol_kinds)
  local symbol_kind_map = {}
  if type(symbol_kinds) == 'string' then
    symbol_kinds = { symbol_kinds }
  end
  if #symbol_kinds > 0 then
    for _, kind_name in ipairs(symbol_kinds) do
      for kind_num, lsp_kind_name in pairs(vim.lsp.protocol.SymbolKind) do
        if lsp_kind_name == kind_name then
          symbol_kind_map[kind_num] = true
          break
        end
      end
    end
  end
  return symbol_kind_map, symbol_kinds
end

-- Flatten and filter symbols recursively with depth limit
local function flatten_symbols(symbols, container_name, symbol_kind_map, symbol_kinds, depth)
  depth = depth or 0
  if depth > 10 then
    return {}
  end -- Prevent infinite recursion
  local flattened = {}
  for _, symbol in ipairs(symbols) do
    if #symbol_kinds == 0 or symbol_kind_map[symbol.kind] then
      local flat_symbol = {
        name = symbol.name,
        kind = symbol.kind,
        containerName = container_name,
        location = symbol.location or { range = symbol.range or symbol.selectionRange },
      }
      table.insert(flattened, flat_symbol)
    end
    if symbol.children then
      local children = flatten_symbols(symbol.children, symbol.name, symbol_kind_map, symbol_kinds, depth + 1)
      for _, child in ipairs(children) do
        table.insert(flattened, child)
      end
    end
  end
  return flattened
end

-- Dual UI for diagnostics: snacks if available, else native
function M.peek_diagnostics()
  local has_snacks, snacks_picker = pcall(require, 'snacks.picker')
  local diagnostics = vim.diagnostic.get(0)
  if #diagnostics == 0 then
    print 'No diagnostics found'
    return
  end
  if M.config.use_snacks and has_snacks then
    local items = {}
    for _, diag in ipairs(diagnostics) do
      table.insert(items, {
        text = string.format('[%s] Line %d:%d - %s', vim.diagnostic.severity[diag.severity], diag.lnum + 1, diag.col + 1, diag.message),
        action = function()
          vim.api.nvim_win_set_cursor(0, { diag.lnum + 1, diag.col })
        end,
      })
    end
    snacks_picker.pick { items = items, prompt = 'Diagnostics' }
  else
    local diagnostics_bufnr, err, diagnostic_data = create_diagnostics_buffer()
    if not diagnostics_bufnr then
      print(err)
      return
    end
    local original_win = vim.api.nvim_get_current_win()
    local current_file = vim.fn.expand '%:t'
    local title = ' Diagnostics @' .. current_file .. ' '
    local win = create_bottom_right_popup(diagnostics_bufnr, title, original_win)
    setup_peek_popup(diagnostics_bufnr, win, original_win, diagnostic_data, 'diagnostic_highlight')
  end
end

-- Dual UI for symbols: snacks if available, else native
function M.peek_symbols(symbol_kinds)
  symbol_kinds = symbol_kinds or {}
  local clients = vim.lsp.get_clients { bufnr = 0 }
  if #clients == 0 then
    print 'No LSP client attached'
    return
  end
  local params = { textDocument = vim.lsp.util.make_text_document_params(0) }
  vim.lsp.buf_request(0, 'textDocument/documentSymbol', params, function(err, result)
    if err or not result or vim.tbl_isempty(result) then
      print 'No symbols found'
      return
    end
    local symbol_kind_map, processed_symbol_kinds = create_symbol_kind_map(symbol_kinds)
    local all_symbols = flatten_symbols(result, nil, symbol_kind_map, processed_symbol_kinds)
    if #all_symbols == 0 then
      local filter_text = #processed_symbol_kinds > 0 and table.concat(processed_symbol_kinds, '/') or 'symbols'
      print('No ' .. filter_text .. ' found')
      return
    end
    local has_snacks, snacks_picker = pcall(require, 'snacks.picker')
    if M.config.use_snacks and has_snacks then
      local items = {}
      for _, sym in ipairs(all_symbols) do
        local kind_name = vim.lsp.protocol.SymbolKind[sym.kind] or 'Unknown'
        local line_num = sym.location.range.start.line + 1
        local text = string.format('%d: %s %s', line_num, kind_name, sym.name)
        if sym.containerName then
          text = text .. ' (' .. sym.containerName .. ')'
        end
        table.insert(items, {
          text = text,
          action = function()
            vim.api.nvim_win_set_cursor(0, { line_num, sym.location.range.start.character })
          end,
        })
      end
      snacks_picker.pick { items = items, prompt = 'Symbols' }
    else
      local original_win = vim.api.nvim_get_current_win()
      local current_file = vim.fn.expand '%:t'
      local filter_text = #processed_symbol_kinds > 0 and table.concat(processed_symbol_kinds, '/') or 'Symbols'
      local symbols_bufnr, _, symbol_data = create_symbols_buffer(all_symbols)
      local symbols_title = ' ' .. filter_text .. ' @' .. current_file .. ' '
      local win = create_bottom_right_popup(symbols_bufnr, symbols_title, original_win)
      setup_peek_popup(symbols_bufnr, win, original_win, symbol_data, 'symbol_highlight')
    end
  end)
end

function M.peek_definition()
  peek_lsp_result('textDocument/definition', 'Definition', 'No definition found')
end

function M.peek_implementation()
  peek_lsp_result('textDocument/implementation', 'Implementation', 'No implementation found')
end

return M
