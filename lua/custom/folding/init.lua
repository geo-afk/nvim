local M = {}

local provider = require("custom.folding.provider")
local preview = require("custom.folding.preview")
local statuscolumn = require("custom.folding.statuscolumn")

M.config = {
  icon = "▶",
  separator = " · ",
  line_count_format = "%d lines",
  shorten_parameters = true,
  strip_block_indicators = true,
  statuscolumn = {
    enabled = true,
    open_icon = "",
    closed_icon = "",
    show_indicators = true,
    signs_first = true,
  },
  keymaps = {
    toggle = "za",
    open = "zo",
    close = "zc",
    open_recursive = "zO",
    close_recursive = "zC",
    open_all = "zR",
    close_all = "zM",
    preview = "K",
    next_fold = "zj",
    prev_fold = "zk",
  }
}

-- Default highlight definitions
local function init_highlights()
  vim.api.nvim_set_hl(0, "FoldedIcon", { link = "Special", default = true })
  vim.api.nvim_set_hl(0, "FoldedSeparator", { link = "Comment", default = true })
  vim.api.nvim_set_hl(0, "FoldedLineCount", { link = "Comment", default = true })
  vim.api.nvim_set_hl(0, "FoldOpenIcon", { link = "Special", default = true })
  vim.api.nvim_set_hl(0, "FoldClosedIcon", { link = "Directory", default = true })
end

--- Retrieves syntax highlighting groups for each byte of a line using Treesitter.
local function get_treesitter_hls(bufnr, lnum, line_len)
  local byte_hls = {}
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if not ok or not parser then return byte_hls end

  local tstree = parser:parse()[1]
  if not tstree then return byte_hls end
  local root = tstree:root()
  local lang = parser:lang()

  local query = vim.treesitter.query.get(lang, "highlights")
  if not query then return byte_hls end

  local line_idx = lnum - 1
  for id, node, _ in query:iter_captures(root, bufnr, line_idx, line_idx + 1) do
    local name = query.captures[id]
    local hl_group = "@" .. name
    local start_row, start_col, end_row, end_col = node:range()
    
    if start_row <= line_idx and end_row >= line_idx then
      local c_start = (start_row == line_idx) and start_col or 0
      local c_end = (end_row == line_idx) and end_col or line_len
      for col = c_start + 1, c_end do
        byte_hls[col] = hl_group
      end
    end
  end

  return byte_hls
end

--- Retrieves syntax highlighting groups for each character of a line using Vim's syntax engine.
local function get_syntax_hls(lnum, line_len)
  local byte_hls = {}
  if vim.bo.syntax == "" then return byte_hls end
  for col = 1, line_len do
    local id = vim.fn.synID(lnum, col, 1)
    local name = vim.fn.synIDattr(id, "name")
    if name ~= "" then
      byte_hls[col] = name
    end
  end
  return byte_hls
end

--- Modifies line content and adjusts the byte-highlight mapping
local function modify_line_with_hls(line, byte_hls)
  -- 1. Shorten parameters: replace first balanced %b() with (...)
  if M.config.shorten_parameters then
    local s_start, s_end = line:find("%b()")
    if s_start and s_end and (s_end - s_start) > 2 then
      local before = line:sub(1, s_start - 1)
      local after = line:sub(s_end + 1)
      
      local new_line = before .. "(...)" .. after
      local new_hls = {}
      
      -- Copy highlights before parenthesis
      for i = 1, s_start - 1 do
        new_hls[i] = byte_hls[i]
      end
      -- Highlight "(...)" with the parenthesis' highlight group
      local paren_hl = byte_hls[s_start] or "Folded"
      for i = s_start, s_start + 4 do
        new_hls[i] = paren_hl
      end
      -- Copy highlights after, shifting index
      local shift = (s_end - s_start + 1) - 5
      for i = s_start + 5, #new_line do
        new_hls[i] = byte_hls[i + shift]
      end
      
      line = new_line
      byte_hls = new_hls
    end
  end

  -- 2. Strip trailing block indicators like {, then, do, etc.
  if M.config.strip_block_indicators then
    local strip_pat = "%s*[%{%}%[%]]+%s*$"
    local strip_start, _ = line:find(strip_pat)
    if not strip_start then
      strip_start, _ = line:find("%s+then%s*$")
    end
    if not strip_start then
      strip_start, _ = line:find("%s+do%s*$")
    end
    
    if strip_start then
      line = line:sub(1, strip_start - 1)
      -- truncate highlights
      for i = strip_start, #byte_hls do
        byte_hls[i] = nil
      end
    end
  end

  return line, byte_hls
end

--- Custom foldtext generator. Returns a list of highlighted tuples.
function M.foldtext()
  local start_lnum = vim.v.foldstart
  local end_lnum = vim.v.foldend
  local fold_level = vim.v.foldlevel

  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_lnum - 1, start_lnum, false)
  local raw_line = lines[1] or ""
  
  -- Extract leading indentation
  local indent_str = raw_line:match("^(%s*)") or ""
  local content_str = raw_line:sub(#indent_str + 1)
  
  -- Gather syntax highlighting of the content part
  local content_len = #content_str
  local byte_hls = get_treesitter_hls(bufnr, start_lnum, #raw_line)
  if vim.tbl_isempty(byte_hls) then
    byte_hls = get_syntax_hls(start_lnum, #raw_line)
  end

  -- Shift content highlights to align with content_str (1-based index)
  local content_hls = {}
  for i = 1, content_len do
    content_hls[i] = byte_hls[i + #indent_str]
  end

  -- Apply modifications
  local clean_content, clean_hls = modify_line_with_hls(content_str, content_hls)

  -- Calculate folded lines count
  local count = end_lnum - start_lnum + 1
  local count_str = string.format(M.config.line_count_format, count)

  -- Build return structure (drawn like overlay virtual text)
  local result = {}
  
  -- 1. Preserve original indentation
  if #indent_str > 0 then
    table.insert(result, { indent_str, "None" })
  end

  -- 2. Add icon with spacing
  table.insert(result, { M.config.icon .. " ", "FoldedIcon" })

  -- 3. Add highlighted line content
  local current_text = ""
  local current_hl = nil
  for i = 1, #clean_content do
    local char = clean_content:sub(i, i)
    local hl = clean_hls[i] or "Folded"
    if hl == current_hl then
      current_text = current_text .. char
    else
      if current_text ~= "" then
        table.insert(result, { current_text, current_hl })
      end
      current_text = char
      current_hl = hl
    end
  end
  if current_text ~= "" then
    table.insert(result, { current_text, current_hl })
  end

  -- 4. Add separator and count
  table.insert(result, { M.config.separator, "FoldedSeparator" })
  table.insert(result, { count_str, "FoldedLineCount" })

  return result
end

--- Custom foldexpr generator
function M.foldexpr()
  local bufnr = vim.api.nvim_get_current_buf()
  local lnum = vim.v.lnum
  return provider.get_fold_expr(bufnr, lnum)
end

-- Public APIs
function M.toggle()
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  if vim.fn.foldclosed(lnum) ~= -1 then
    vim.cmd("normal! zo")
  else
    pcall(vim.cmd, "normal! zc")
  end
end

function M.open() vim.cmd("normal! zo") end
function M.close() vim.cmd("normal! zc") end
function M.open_recursive() vim.cmd("normal! zO") end
function M.close_recursive() vim.cmd("normal! zC") end
function M.open_all() vim.cmd("normal! zR") end
function M.close_all() vim.cmd("normal! zM") end
function M.next() vim.cmd("normal! zj") end
function M.prev() vim.cmd("normal! zk") end
function M.preview() preview.show_preview() end

--- Configures options on a window for custom folding
local function apply_win_options(win)
  if not vim.api.nvim_win_is_valid(win) then return end
  local buf = vim.api.nvim_win_get_buf(win)
  
  -- We don't apply folding options on special buffers
  local bt = vim.bo[buf].buftype
  if bt ~= "" then return end

  vim.wo[win].foldmethod = "expr"
  vim.wo[win].foldexpr = "v:lua.custom_folding_expr()"
  vim.wo[win].foldtext = "v:lua.custom_folding_text()"
  
  if M.config.statuscolumn.enabled then
    vim.wo[win].statuscolumn = "%{%v:lua.custom_folding_statuscolumn()%}"
  end
end

--- Main setup entrypoint
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  statuscolumn.config = vim.tbl_deep_extend("force", statuscolumn.config, M.config.statuscolumn or {})
  
  init_highlights()

  -- Register global functions for Vimscript evaluation
  _G.custom_folding_expr = M.foldexpr
  _G.custom_folding_text = M.foldtext
  _G.custom_folding_click = statuscolumn.click_handler
  _G.custom_folding_statuscolumn = statuscolumn.build_statuscolumn

  -- Setup keymaps
  if M.config.keymaps ~= false then
    local keymaps = M.config.keymaps
    if keymaps.toggle then vim.keymap.set("n", keymaps.toggle, M.toggle, { desc = "Toggle fold" }) end
    if keymaps.open then vim.keymap.set("n", keymaps.open, M.open, { desc = "Open fold" }) end
    if keymaps.close then vim.keymap.set("n", keymaps.close, M.close, { desc = "Close fold" }) end
    if keymaps.open_recursive then vim.keymap.set("n", keymaps.open_recursive, M.open_recursive, { desc = "Recursive open fold" }) end
    if keymaps.close_recursive then vim.keymap.set("n", keymaps.close_recursive, M.close_recursive, { desc = "Recursive close fold" }) end
    if keymaps.open_all then vim.keymap.set("n", keymaps.open_all, M.open_all, { desc = "Open all folds" }) end
    if keymaps.close_all then vim.keymap.set("n", keymaps.close_all, M.close_all, { desc = "Close all folds" }) end
    if keymaps.preview then vim.keymap.set("n", keymaps.preview, M.preview, { desc = "Preview fold" }) end
    if keymaps.next_fold then vim.keymap.set("n", keymaps.next_fold, M.next, { desc = "Next fold" }) end
    if keymaps.prev_fold then vim.keymap.set("n", keymaps.prev_fold, M.prev, { desc = "Previous fold" }) end
  end

  -- Apply to all existing windows
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    apply_win_options(win)
  end

  -- Automatically manage buffer loading, changes, and window focus
  local group = vim.api.nvim_create_augroup("CustomFoldingSystem", { clear = true })
  
  vim.api.nvim_create_autocmd({ "BufReadPost", "FileType", "LspAttach" }, {
    group = group,
    callback = function(ev)
      provider.update_folds(ev.buf)
    end,
  })

  vim.api.nvim_create_autocmd({ "TextChanged", "InsertLeave" }, {
    group = group,
    callback = function(ev)
      provider.update_folds(ev.buf)
    end,
  })

  vim.api.nvim_create_autocmd({ "BufUnload" }, {
    group = group,
    callback = function(ev)
      provider.clear_buffer(ev.buf)
    end,
  })

  vim.api.nvim_create_autocmd({ "BufWinEnter", "WinEnter" }, {
    group = group,
    callback = function()
      local win = vim.api.nvim_get_current_win()
      apply_win_options(win)
    end,
  })
end

return M
