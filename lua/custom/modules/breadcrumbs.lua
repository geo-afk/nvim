-- Try loading devicons safely
local devicons_ok, devicons = pcall(require, 'nvim-web-devicons')

-- Fallback icons
local folder_icon = '%#Conditional#' .. '󰉋' .. '%#Normal#'
local file_icon = '󰈙'

-- Symbol kinds (LSP kinds)
local kind_icons = {
  '%#File#' .. '󰈙' .. '%#Normal#', -- file
  '%#Module#' .. '' .. '%#Normal#', -- module
  '%#Structure#' .. '' .. '%#Normal#', -- namespace
  '%#Keyword#' .. '󰌋' .. '%#Normal#', -- keyword
  '%#Class#' .. '󰠱' .. '%#Normal#', -- class
  '%#Method#' .. '󰆧' .. '%#Normal#', -- method
  '%#Property#' .. '󰜢' .. '%#Normal#', -- property
  '%#Field#' .. '󰇽' .. '%#Normal#', -- field
  '%#Function#' .. '' .. '%#Normal#', -- constructor
  '%#Enum#' .. '' .. '%#Normal#', -- enum
  '%#Type#' .. '' .. '%#Normal#', -- interface
  '%#Function#' .. '󰊕' .. '%#Normal#', -- function
  '%#None#' .. '󰂡' .. '%#Normal#', -- variable
  '%#Constant#' .. '󰏿' .. '%#Normal#', -- constant
  '%#String#' .. '' .. '%#Normal#', -- string
  '%#Number#' .. '' .. '%#Normal#', -- number
  '%#Boolean#' .. '' .. '%#Normal#', -- boolean
  '%#Array#' .. '' .. '%#Normal#', -- array
  '%#Class#' .. '' .. '%#Normal#', -- object
  '', -- package
  '󰟢', -- null
  '', -- enum-member
  '%#Struct#' .. '' .. '%#Normal#', -- struct
  '', -- event
  '', -- operator
  '󰅲', -- type-parameter
}

-- Cache for symbols per buffer
local symbols_cache = {}

-- Polyfill for vim.debounce
local function debounce(fn, ms)
  local timer = vim.loop.new_timer()
  return function(...)
    local args = { ... }
    timer:stop()
    timer:start(
      ms,
      0,
      vim.schedule_wrap(function()
        fn(unpack(args))
      end)
    )
  end
end

-- Utility: check if position is within LSP range
local function range_contains_pos(range, line, char)
  local start = range.start
  local stop = range['end']

  if line < start.line or line > stop.line then
    return false
  end
  if line == start.line and char < start.character then
    return false
  end
  if line == stop.line and char > stop.character then
    return false
  end
  return true
end

-- Recursive symbol finder with optional depth limit
local function find_symbol_path(symbol_list, line, char, path, depth, max_depth)
  if not symbol_list or #symbol_list == 0 then
    return false
  end
  if depth and depth > max_depth then
    table.insert(path, '%#Comment#...%#Normal#')
    return true
  end
  for _, symbol in ipairs(symbol_list) do
    if range_contains_pos(symbol.range, line, char) then
      local icon = kind_icons[symbol.kind] or ''
      table.insert(path, icon .. ' ' .. symbol.name)
      find_symbol_path(symbol.children, line, char, path, (depth or 0) + 1, max_depth or 5)
      return true
    end
  end
  return false
end

-- LSP callback to build breadcrumbs
local function lsp_callback(err, symbols, ctx, _)
  if err or not symbols then
    symbols_cache[ctx.bufnr] = nil
    vim.o.winbar = ''
    return
  end

  symbols_cache[ctx.bufnr] = symbols

  local winnr = vim.api.nvim_get_current_win()
  local pos = vim.api.nvim_win_get_cursor(0)
  local cursor_line = pos[1] - 1
  local cursor_char = pos[2]

  local file_path = vim.fn.bufname(ctx.bufnr)
  if not file_path or file_path == '' then
    vim.api.nvim_set_option_value('winbar', '[No Name]', { win = winnr })
    return
  end

  local breadcrumbs = {}
  local file_name = vim.fn.fnamemodify(file_path, ':t:r')
  if file_name == '' then
    file_name = vim.fn.fnamemodify(file_path, ':t')
  end

  local icon
  local icon_hl

  if devicons_ok then
    icon, icon_hl = devicons.get_icon(file_path)
  end

  icon_hl = icon_hl or 'Normal'
  icon = icon or file_icon

  table.insert(breadcrumbs, '%#' .. icon_hl .. '#' .. icon .. '%#Normal#' .. ' ' .. file_name)

  -- Add symbol path with depth limit
  find_symbol_path(symbols, cursor_line, cursor_char, breadcrumbs, 0, 5)

  local breadcrumb_string = table.concat(breadcrumbs, ' > ')
  vim.api.nvim_set_option_value('winbar', breadcrumb_string ~= '' and breadcrumb_string or ' ', { win = winnr })
end

-- Request symbols for current buffer
local function breadcrumbs_set()
  local bufnr = vim.api.nvim_get_current_buf()
  local uri = vim.lsp.util.make_text_document_params(bufnr).uri
  if not uri then
    vim.print 'Error: Could not get URI for buffer. Is it saved?'
    return
  end

  local buf_src = uri:sub(1, uri:find ':' - 1)
  if buf_src ~= 'file' then
    vim.o.winbar = ''
    return
  end

  -- Use cached symbols if available
  if symbols_cache[bufnr] then
    lsp_callback(nil, symbols_cache[bufnr], { bufnr = bufnr }, nil)
    return
  end

  local params = { textDocument = { uri = uri } }
  vim.lsp.buf_request(bufnr, 'textDocument/documentSymbol', params, lsp_callback)
end

-- Debounced version for cursor moves
local debounced_breadcrumbs_set = debounce(breadcrumbs_set, 150)

-- Autocommands
local breadcrumbs_augroup = vim.api.nvim_create_augroup('Breadcrumbs', { clear = true })

vim.api.nvim_create_autocmd({ 'CursorMoved' }, {
  group = breadcrumbs_augroup,
  callback = debounced_breadcrumbs_set,
  desc = 'Update breadcrumbs on cursor move (debounced)',
})

vim.api.nvim_create_autocmd({ 'WinLeave' }, {
  group = breadcrumbs_augroup,
  callback = function()
    vim.o.winbar = ''
  end,
  desc = 'Clear breadcrumbs when leaving window',
})

-- Invalidate cache on buffer write
vim.api.nvim_create_autocmd({ 'BufWritePost' }, {
  group = breadcrumbs_augroup,
  callback = function()
    local bufnr = vim.api.nvim_get_current_buf()
    symbols_cache[bufnr] = nil
  end,
  desc = 'Invalidate symbol cache on buffer write',
})

-- Prefetch symbols on buffer enter for better initial performance
vim.api.nvim_create_autocmd({ 'BufEnter' }, {
  group = breadcrumbs_augroup,
  callback = breadcrumbs_set,
  desc = 'Prefetch breadcrumbs on buffer enter',
})
