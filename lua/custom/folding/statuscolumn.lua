local M = {}
local provider = require("custom.folding.provider")

M.config = {
  open_icon = "",
  closed_icon = "",
  show_indicators = true,
  signs_first = true,
}

--- Handles statuscolumn click events
function M.click_handler(minwid, clicks, button, mods)
  local mousepos = vim.fn.getmousepos()
  local winid = mousepos.winid
  local lnum = mousepos.line
  
  if not winid or not vim.api.nvim_win_is_valid(winid) then return end

  -- Perform the fold operation inside the clicked window's context
  vim.api.nvim_win_call(winid, function()
    local cursor = vim.api.nvim_win_get_cursor(winid)
    pcall(vim.api.nvim_win_set_cursor, winid, { lnum, 0 })
    
    if vim.fn.foldclosed(lnum) ~= -1 then
      vim.cmd("normal! zo")
    else
      -- Toggle the fold under cursor. Since zc can fail if not on a fold,
      -- we wrap it in a pcall.
      pcall(vim.cmd, "normal! zc")
    end
    
    pcall(vim.api.nvim_win_set_cursor, winid, cursor)
  end)
end

--- Builds the statuscolumn string dynamically for the line v:lnum
function M.build_statuscolumn()
  local lnum = vim.v.lnum
  local winid = vim.g.statusline_winid or vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_win_get_buf(winid)

  local is_start = false
  local cache = provider.caches[bufnr]
  
  if cache and cache.expr_vals then
    local val = cache.expr_vals[lnum]
    if val and val:sub(1, 1) == ">" then
      is_start = true
    end
  else
    local lvl = vim.fn.foldlevel(lnum)
    local prev_lvl = (lnum > 1) and vim.fn.foldlevel(lnum - 1) or 0
    if lvl > prev_lvl then
      is_start = true
    end
  end

  local fold_indicator = " "
  if is_start and M.config.show_indicators then
    local is_closed = vim.fn.foldclosed(lnum) ~= -1
    if is_closed then
      fold_indicator = "%#FoldClosedIcon#" .. M.config.closed_icon .. "%*"
    else
      fold_indicator = "%#FoldOpenIcon#" .. M.config.open_icon .. "%*"
    end
  end

  local click_start = "%@v:lua.custom_folding_click@"
  local click_end = "%X"

  local num_str = ""
  if vim.wo[winid].number then
    if vim.wo[winid].relativenumber then
      local relnum = vim.v.relnum
      num_str = (relnum == 0) and "%l" or "%r"
    else
      num_str = "%l"
    end
  end

  local signs = "%s"
  local fold_col = click_start .. fold_indicator .. click_end
  -- Pad the line number slightly for clean alignment
  local pad = " "
  local num_col = click_start .. num_str .. click_end

  if M.config.signs_first then
    return signs .. pad .. fold_col .. pad .. num_col .. pad .. "│"
  else
    return fold_col .. pad .. num_col .. pad .. signs .. pad .. "│"
  end
end

return M
