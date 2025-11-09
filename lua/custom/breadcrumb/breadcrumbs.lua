vim.lsp.breadcrumbs = {
  enabled = true,
}

-- Safely try to load nvim-web-devicons
local devicons_ok, devicons = pcall(require, "nvim-web-devicons")

-- Default icons
local folder_icon = "%#Conditional#" .. "󰉋" .. "%#Normal#"
local file_icon = "󰈙"

-- Map of LSP SymbolKind to string icon (optimized: local reference)
local kind_icons = {
  [1] = "%#File#" .. "󰈙" .. "%#Normal#",
  [2] = "%#Module#" .. "󰠱" .. "%#Normal#",
  [3] = "%#Structure#" .. "" .. "%#Normal#",
  [4] = "",
  [5] = "%#Class#" .. "" .. "%#Normal#",
  [6] = "%#Method#" .. "󰆧" .. "%#Normal#",
  [7] = "%#Property#" .. "" .. "%#Normal#",
  [8] = "%#Field#" .. "" .. "%#Normal#",
  [9] = "%#Function#" .. "" .. "%#Normal#",
  [10] = "%#Enum#" .. "" .. "%#Normal#",
  [11] = "%#Type#" .. "" .. "%#Normal#",
  [12] = "%#Function#" .. "󰊕" .. "%#Normal#",
  [13] = "%#None#" .. "󰂡" .. "%#Normal#",
  [14] = "%#Constant#" .. "󰏿" .. "%#Normal#",
  [15] = "%#String#" .. "" .. "%#Normal#",
  [16] = "%#Number#" .. "" .. "%#Normal#",
  [17] = "%#Boolean#" .. "" .. "%#Normal#",
  [18] = "%#Array#" .. "" .. "%#Normal#",
  [19] = "%#Keyword#" .. "󰌋" .. "%#Normal#",
  [20] = "%#Class#" .. "" .. "%#Normal#",
  [21] = "󰟢",
  [22] = "",
  [23] = "%#Struct#" .. "" .. "%#Normal#",
  [24] = "",
  [25] = "",
  [26] = "󰅲",
}

-- Cache for symbol data (per buffer)
local symbol_cache = {}
local last_position = {}

-- Debounce implementation using vim.uv.new_timer()
local function debounce(fn, ms)
  local timer = vim.uv.new_timer()
  local function wrapped_fn(...)
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
  return wrapped_fn, timer
end

--- Checks if a cursor position is inside an LSP range (optimized: early returns)
local function range_contains_pos(range, line, char)
  local start = range.start
  local stop = range["end"]

  -- Fast path rejections
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

--- Recursively finds the symbol path at cursor position (optimized: early return)
local function find_symbol_path(symbol_list, line, char, path)
  if not symbol_list then
    return false
  end

  for _, symbol in ipairs(symbol_list) do
    if range_contains_pos(symbol.range, line, char) then
      local icon = kind_icons[symbol.kind] or ""
      table.insert(path, icon .. " " .. symbol.name)
      find_symbol_path(symbol.children, line, char, path)
      return true
    end
  end
  return false
end

--- LSP callback (optimized: caching and early exits)
local function lsp_callback(err, symbols, ctx, config)
  if err or not symbols then
    vim.o.winbar = ""
    return
  end

  local bufnr = ctx.bufnr
  local winnr = vim.api.nvim_get_current_win()

  -- Cache symbols for this buffer
  symbol_cache[bufnr] = symbols

  local pos = vim.api.nvim_win_get_cursor(winnr)
  local cursor_line = pos[1] - 1
  local cursor_char = pos[2]

  local file_path = vim.fn.bufname(bufnr)
  if not file_path or file_path == "" then
    vim.api.nvim_set_option_value("winbar", "[No Name]", { win = winnr })
    return
  end

  -- Get relative path (optimized: single client check)
  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  local relative_path

  if #clients > 0 and clients[1].root_dir then
    relative_path = vim.fn.fnamemodify(file_path, ":~:." .. clients[1].root_dir)
  else
    relative_path = vim.fn.fnamemodify(file_path, ":~:.")
  end

  local breadcrumbs = {}

  -- Split path and build file path part
  local path_components = vim.split(relative_path, "[/\\]", { trimempty = true })
  local num_components = #path_components

  for i, component in ipairs(path_components) do
    if i == num_components then
      -- Last component is file name
      local icon, icon_hl
      if devicons_ok then
        icon, icon_hl = devicons.get_icon(component)
      end
      table.insert(
        breadcrumbs,
        "%#" .. (icon_hl or "Normal") .. "#" .. (icon or file_icon) .. "%#Normal#" .. " " .. component
      )
    else
      -- Folder component
      table.insert(breadcrumbs, folder_icon .. " " .. component)
    end
  end

  -- Find and append symbol path
  find_symbol_path(symbols, cursor_line, cursor_char, breadcrumbs)

  local breadcrumb_string = table.concat(breadcrumbs, " > ")

  if breadcrumb_string ~= "" then
    vim.api.nvim_set_option_value("winbar", breadcrumb_string, { win = winnr })
  else
    vim.api.nvim_set_option_value("winbar", " ", { win = winnr })
  end
end

--- Fast path: Update breadcrumbs using cached symbols
local function breadcrumbs_update_fast()
  if not vim.lsp.breadcrumbs.enabled then
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local winnr = vim.api.nvim_get_current_win()

  -- Check if we have cached symbols
  local symbols = symbol_cache[bufnr]
  if not symbols then
    return -- No cache, will be updated by full request
  end

  local pos = vim.api.nvim_win_get_cursor(winnr)
  local cursor_line = pos[1] - 1
  local cursor_char = pos[2]

  -- Check if position changed significantly
  local last_pos = last_position[bufnr]
  if last_pos and last_pos[1] == cursor_line and math.abs(last_pos[2] - cursor_char) < 5 then
    return -- Position hasn't changed enough
  end

  last_position[bufnr] = { cursor_line, cursor_char }

  local file_path = vim.fn.bufname(bufnr)
  if not file_path or file_path == "" then
    return
  end

  -- Build breadcrumbs using cached symbols
  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  local relative_path

  if #clients > 0 and clients[1].root_dir then
    relative_path = vim.fn.fnamemodify(file_path, ":~:." .. clients[1].root_dir)
  else
    relative_path = vim.fn.fnamemodify(file_path, ":~:.")
  end

  local breadcrumbs = {}
  local path_components = vim.split(relative_path, "[/\\]", { trimempty = true })
  local num_components = #path_components

  for i, component in ipairs(path_components) do
    if i == num_components then
      local icon, icon_hl
      if devicons_ok then
        icon, icon_hl = devicons.get_icon(component)
      end
      table.insert(
        breadcrumbs,
        "%#" .. (icon_hl or "Normal") .. "#" .. (icon or file_icon) .. "%#Normal#" .. " " .. component
      )
    else
      table.insert(breadcrumbs, folder_icon .. " " .. component)
    end
  end

  find_symbol_path(symbols, cursor_line, cursor_char, breadcrumbs)

  local breadcrumb_string = table.concat(breadcrumbs, " > ")
  if breadcrumb_string ~= "" then
    vim.api.nvim_set_option_value("winbar", breadcrumb_string, { win = winnr })
  end
end

--- Full update: Request symbols from LSP
local function breadcrumbs_set()
  if not vim.lsp.breadcrumbs.enabled then
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ bufnr = bufnr })

  if #clients == 0 then
    return
  end

  -- Check if client supports documentSymbol
  if not clients[1].supports_method("textDocument/documentSymbol") then
    return
  end

  local params = vim.lsp.util.make_text_document_params(bufnr)

  -- Don't run on non-file buffers
  if not params.uri or not params.uri:match("^file://") then
    vim.o.winbar = ""
    return
  end

  -- Make async LSP request
  pcall(vim.lsp.buf_request, bufnr, "textDocument/documentSymbol", params, lsp_callback)
end

-- Create debounced versions
local breadcrumbs_set_debounced, debounce_timer = debounce(breadcrumbs_set, 300)

-- Create augroup
local breadcrumbs_augroup = vim.api.nvim_create_augroup("Breadcrumbs", { clear = true })

-- Use CursorHold for full LSP requests (debounced)
vim.api.nvim_create_autocmd("CursorHold", {
  group = breadcrumbs_augroup,
  callback = breadcrumbs_set_debounced,
  desc = "Set breadcrumbs (debounced)",
})

-- Use CursorMoved for fast cache-based updates
vim.api.nvim_create_autocmd("CursorMoved", {
  group = breadcrumbs_augroup,
  callback = breadcrumbs_update_fast,
  desc = "Update breadcrumbs (cached)",
})

-- Request fresh symbols when LSP attaches or buffer changes
vim.api.nvim_create_autocmd({ "LspAttach", "BufEnter" }, {
  group = breadcrumbs_augroup,
  callback = function()
    vim.defer_fn(breadcrumbs_set, 100)
  end,
  desc = "Refresh breadcrumbs on attach/enter",
})

-- Clear cache and winbar when leaving
vim.api.nvim_create_autocmd("BufLeave", {
  group = breadcrumbs_augroup,
  callback = function(args)
    symbol_cache[args.buf] = nil
    last_position[args.buf] = nil
  end,
  desc = "Clear breadcrumbs cache",
})

vim.api.nvim_create_autocmd("WinLeave", {
  group = breadcrumbs_augroup,
  callback = function()
    vim.o.winbar = ""
  end,
  desc = "Clear breadcrumbs when leaving window",
})

local function toggle_breadcrumbs()
  if not vim.lsp.breadcrumbs or vim.lsp.breadcrumbs.enabled == nil then
    vim.notify("`vim.lsp.breadcrumbs.enabled` doesn't exist!", vim.log.levels.WARN, { title = "LSP" })
    return
  end

  vim.lsp.breadcrumbs.enabled = not vim.lsp.breadcrumbs.enabled

  if vim.lsp.breadcrumbs.enabled then
    vim.notify("Breadcrumbs enabled", vim.log.levels.INFO, { title = "LSP" })
    breadcrumbs_set()
  else
    vim.notify("Breadcrumbs disabled", vim.log.levels.INFO, { title = "LSP" })
    vim.o.winbar = ""
    -- Clear cache
    symbol_cache = {}
    last_position = {}
  end
end

vim.keymap.set("n", "<leader><leader>TB", toggle_breadcrumbs, {
  desc = "Toggle LSP breadcrumbs",
  noremap = true,
  silent = true,
})
