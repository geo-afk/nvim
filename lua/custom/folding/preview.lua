local M = {}

local preview_win = nil
local preview_buf = nil
local preview_start_lnum = nil
local preview_origin_win = nil

--- Closes the active preview window and cleans up variables
function M.close_preview()
  if preview_win and vim.api.nvim_win_is_valid(preview_win) then
    vim.api.nvim_win_close(preview_win, true)
  end
  preview_win = nil
  preview_buf = nil
  preview_start_lnum = nil
  preview_origin_win = nil
end

--- Opens a preview of the folded range at the cursor line in a floating window.
function M.show_preview()
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(win)
  local lnum = cursor[1]
  
  local f_start = vim.fn.foldclosed(lnum)
  if f_start == -1 then
    M.close_preview()
    return
  end

  -- If preview is already open for this exact fold, do not recreate it
  if preview_win and vim.api.nvim_win_is_valid(preview_win) and preview_start_lnum == f_start and preview_origin_win == win then
    return
  end

  M.close_preview()

  local f_end = vim.fn.foldclosedend(lnum)
  local lines = vim.api.nvim_buf_get_lines(buf, f_start - 1, f_end, false)
  if #lines == 0 then return end

  -- Create scratch buffer for preview
  preview_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, lines)

  -- Preserve filetype/syntax to trigger highlights
  local ft = vim.bo[buf].filetype
  local syn = vim.bo[buf].syntax
  vim.api.nvim_set_option_value("filetype", ft, { buf = preview_buf })
  vim.api.nvim_set_option_value("syntax", syn, { buf = preview_buf })

  -- Size the floating window
  local max_w = 0
  for _, line in ipairs(lines) do
    local w = vim.fn.strdisplaywidth(line)
    if w > max_w then max_w = w end
  end

  local win_width = vim.api.nvim_win_get_width(win)
  local width = math.min(max_w + 4, win_width - 8)
  width = math.max(width, 1)

  local win_height = vim.api.nvim_win_get_height(win)
  local height = math.min(#lines, 15) -- Cap at 15 lines
  height = math.min(height, win_height - 2)
  height = math.max(height, 1)

  -- Position the floating window
  local opts = {
    relative = "cursor",
    row = 1,
    col = 0,
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    focusable = false,
  }

  preview_win = vim.api.nvim_open_win(preview_buf, false, opts)
  preview_start_lnum = f_start
  preview_origin_win = win

  -- Apply window styling and hide folds in preview
  vim.api.nvim_set_option_value("foldenable", false, { win = preview_win })
  vim.api.nvim_set_option_value("wrap", false, { win = preview_win })
  vim.api.nvim_set_option_value("winblend", 5, { win = preview_win })

  -- Copy diagnostics in the folded range to the preview buffer
  local diags = vim.diagnostic.get(buf)
  local preview_diags = {}
  for _, d in ipairs(diags) do
    if d.lnum >= f_start - 1 and d.lnum < f_end then
      local cloned = vim.deepcopy(d)
      cloned.bufnr = preview_buf
      -- Translate line numbers to match the preview buffer
      cloned.lnum = d.lnum - (f_start - 1)
      if d.end_lnum then
        cloned.end_lnum = d.end_lnum - (f_start - 1)
      end
      table.insert(preview_diags, cloned)
    end
  end

  if #preview_diags > 0 then
    local ns = vim.api.nvim_create_namespace("FoldPreviewDiagnostics")
    vim.diagnostic.set(ns, preview_buf, preview_diags)
  end

  -- Auto-close when the cursor moves off the folded line or window focus changes
  local group = vim.api.nvim_create_augroup("FoldPreviewAutoClose", { clear = true })
  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "BufLeave", "WinLeave", "InsertEnter" }, {
    group = group,
    callback = function()
      if not preview_win or not vim.api.nvim_win_is_valid(preview_win) then
        pcall(vim.api.nvim_del_augroup_by_id, group)
        return
      end

      local current_win = vim.api.nvim_get_current_win()
      if current_win ~= preview_origin_win then
        M.close_preview()
        pcall(vim.api.nvim_del_augroup_by_id, group)
        return
      end

      local cur_lnum = vim.api.nvim_win_get_cursor(preview_origin_win)[1]
      if vim.fn.foldclosed(cur_lnum) ~= f_start then
        M.close_preview()
        pcall(vim.api.nvim_del_augroup_by_id, group)
      end
    end
  })
end

return M
