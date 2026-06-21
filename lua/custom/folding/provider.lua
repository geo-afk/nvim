local M = {}

-- Cache structure:
-- M.caches[bufnr] = {
--   expr_vals = { [lnum] = "level" }, -- e.g., ">1", "1", "0"
--   ranges = { { start_line = number, end_line = number, level = number } },
--   provider = "lsp" | "treesitter" | "indent",
--   last_updated = number
-- }
M.caches = {}
local update_timers = {}

--- Calculates fold levels from a list of start/end ranges.
--- Uses a sweep-line interval nesting algorithm running in O(R log R) time.
--- Returns an array of expr strings for foldexpr, and the nested ranges with levels.
local function calculate_levels(line_count, ranges)
  local levels = {}
  local starts = {}
  for i = 1, line_count do
    levels[i] = 0
  end

  if #ranges == 0 then
    local expr_vals = {}
    for i = 1, line_count do
      expr_vals[i] = "0"
    end
    return expr_vals, {}
  end

  -- Sort ranges: start_line ascending, then end_line descending (outermost first)
  table.sort(ranges, function(a, b)
    if a.start_line ~= b.start_line then
      return a.start_line < b.start_line
    else
      return a.end_line > b.end_line
    end
  end)

  -- Sweep-line stack algorithm to assign nesting levels
  local stack = {}
  local nested_ranges = {}
  for _, range in ipairs(ranges) do
    -- Remove ranges from stack that are completely before the current range
    while #stack > 0 and stack[#stack].end_line < range.start_line do
      table.remove(stack)
    end

    -- Nesting level is the stack depth + 1
    local lvl = #stack + 1
    local r_entry = {
      start_line = range.start_line,
      end_line = range.end_line,
      level = lvl
    }
    table.insert(stack, r_entry)
    table.insert(nested_ranges, r_entry)

    -- Fill levels and starts
    for lnum = r_entry.start_line, r_entry.end_line do
      levels[lnum] = math.max(levels[lnum], lvl)
    end
    starts[r_entry.start_line] = math.max(starts[r_entry.start_line] or 0, lvl)
  end

  -- Generate the foldexpr strings
  local expr_vals = {}
  for lnum = 1, line_count do
    if starts[lnum] then
      expr_vals[lnum] = ">" .. starts[lnum]
    else
      expr_vals[lnum] = tostring(levels[lnum])
    end
  end

  return expr_vals, nested_ranges
end

--- Updates the fold cache for a buffer and notifies active windows
local function update_cache(bufnr, expr_vals, ranges, provider)
  M.caches[bufnr] = {
    expr_vals = expr_vals,
    ranges = ranges,
    provider = provider,
    last_updated = vim.uv.now()
  }

  -- Trigger redraw/re-evaluation on windows displaying this buffer
  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(bufnr) then return end
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == bufnr then
        if vim.wo[win].foldmethod == "expr" then
          pcall(vim.api.nvim_win_call, win, function()
            vim.cmd("let &l:foldmethod = &l:foldmethod")
          end)
        end
      end
    end
  end)
end

--- Requests folding ranges from LSP clients attached to the buffer.
--- Returns true if an LSP provider is available and the request is sent.
local function request_lsp_folds(bufnr)
  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  local has_provider = false

  for _, client in ipairs(clients) do
    if client.server_capabilities.foldingRangeProvider then
      has_provider = true
      vim.lsp.buf_request(bufnr, "textDocument/foldingRange", {
        textDocument = vim.lsp.util.make_text_document_params(bufnr)
      }, function(err, result, ctx)
        if err or not result or not vim.api.nvim_buf_is_valid(bufnr) then return end
        
        local ranges = {}
        for _, r in ipairs(result) do
          -- LSP startLine and endLine are 0-indexed.
          -- Often the last line of the fold has its parameters included,
          -- but we want line-based folds. We map to 1-indexed.
          local start_l = r.startLine + 1
          local end_l = r.endLine + 1
          if end_l > start_l then
            table.insert(ranges, { start_line = start_l, end_line = end_l })
          end
        end

        local line_count = vim.api.nvim_buf_line_count(bufnr)
        local expr_vals, nested = calculate_levels(line_count, ranges)
        update_cache(bufnr, expr_vals, nested, "lsp")
      end)
      break
    end
  end

  return has_provider
end

--- Computes fold ranges using Treesitter queries.
--- Returns true if Treesitter folds were successfully computed.
local function compute_treesitter_folds(bufnr)
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if not ok or not parser then return false end

  local lang = parser:lang()
  local query = vim.treesitter.query.get(lang, "folds")
  if not query then return false end

  local ranges = {}
  parser:parse()
  parser:for_each_tree(function(tstree, tree_lang)
    local query_local = vim.treesitter.query.get(tree_lang, "folds")
    if not query_local then return end
    
    local root = tstree:root()
    for id, node, _ in query_local:iter_captures(root, bufnr, 0, -1) do
      local start_row, _, end_row, _ = node:range()
      -- end_row is end-exclusive.
      -- start_row + 1 to end_row represents 1-indexed line ranges.
      local start_l = start_row + 1
      local end_l = end_row
      if end_l > start_l then
        table.insert(ranges, { start_line = start_l, end_line = end_l })
      end
    end
  end)

  local line_count = vim.api.nvim_buf_line_count(bufnr)
  local expr_vals, nested = calculate_levels(line_count, ranges)
  update_cache(bufnr, expr_vals, nested, "treesitter")
  return true
end

--- Computes fold levels using indentation as a fallback
local function compute_indent_folds(bufnr)
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  local shiftwidth = vim.api.nvim_get_option_value("shiftwidth", { buf = bufnr }) or 2
  local tabstop = vim.api.nvim_get_option_value("tabstop", { buf = bufnr }) or 8
  local raw_levels = {}

  for lnum = 1, line_count do
    local lines = vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)
    local line = lines[1] or ""
    if line:match("^%s*$") then
      raw_levels[lnum] = -1 -- mark as undefined/empty
    else
      -- Calculate indentation width manually
      local indent = 0
      for i = 1, #line do
        local char = line:sub(i, i)
        if char == " " then
          indent = indent + 1
        elseif char == "\t" then
          indent = indent + tabstop
        else
          break
        end
      end
      raw_levels[lnum] = math.floor(indent / shiftwidth)
    end
  end

  -- Resolve undefined fold levels (empty lines)
  for lnum = 1, line_count do
    if raw_levels[lnum] == -1 then
      local prev_lvl = raw_levels[lnum - 1] or 0
      local next_lvl = 0
      for i = lnum + 1, line_count do
        if raw_levels[i] ~= -1 then
          next_lvl = raw_levels[i]
          break
        end
      end
      raw_levels[lnum] = math.min(prev_lvl, next_lvl)
    end
  end

  -- Convert level transitions to starts and levels
  local expr_vals = {}
  for lnum = 1, line_count do
    local lvl = raw_levels[lnum]
    local prev_lvl = raw_levels[lnum - 1] or 0
    if lvl > prev_lvl then
      expr_vals[lnum] = ">" .. lvl
    else
      expr_vals[lnum] = tostring(lvl)
    end
  end

  update_cache(bufnr, expr_vals, {}, "indent")
end

--- Main function to recalculate folds for a buffer (debounced)
function M.update_folds(bufnr)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then return end

  if update_timers[bufnr] then
    update_timers[bufnr]:stop()
    update_timers[bufnr]:close()
    update_timers[bufnr] = nil
  end

  local timer = vim.uv.new_timer()
  update_timers[bufnr] = timer
  timer:start(150, 0, vim.schedule_wrap(function()
    if not vim.api.nvim_buf_is_valid(bufnr) then return end
    
    -- Chain calculation: LSP -> Treesitter -> Indent
    local lsp_ok = request_lsp_folds(bufnr)
    if not lsp_ok then
      local ts_ok = compute_treesitter_folds(bufnr)
      if not ts_ok then
        compute_indent_folds(bufnr)
      end
    end

    if update_timers[bufnr] then
      update_timers[bufnr]:close()
      update_timers[bufnr] = nil
    end
  end))
end

--- Returns the foldexpr value for a buffer line
function M.get_fold_expr(bufnr, lnum)
  local cache = M.caches[bufnr]
  if not cache or not cache.expr_vals then
    -- Trigger lazy load if not cached yet, but avoid restarting an already-active timer
    -- (Neovim calls get_fold_expr once per visible line; without this guard, each call
    -- would stop, close, and recreate the uv timer for every line in the buffer.)
    if not update_timers[bufnr] then
      M.update_folds(bufnr)
    end
    return "0"
  end
  return cache.expr_vals[lnum] or "0"
end

--- Clear buffer state on unload
function M.clear_buffer(bufnr)
  M.caches[bufnr] = nil
  if update_timers[bufnr] then
    update_timers[bufnr]:stop()
    update_timers[bufnr]:close()
    update_timers[bufnr] = nil
  end
end

return M
