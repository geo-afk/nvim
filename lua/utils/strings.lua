local M = {}
local api = vim.api

--- Escape special pattern characters for safe string replacement
--- @param pattern string The pattern to escape
--- @return string The escaped pattern
M.escape_pattern = function(pattern)
  local special_chars = '[]\\.*$^+()?{}|='
  return pattern:gsub('[' .. special_chars .. ']', '\\%1')
end

--- Count occurrences of a word in the current buffer
--- @param word string The word to count
--- @return number The number of occurrences
local function count_occurrences(word)
  local count = 0
  local escaped = M.escape_pattern(word)

  for _, line in ipairs(api.nvim_buf_get_lines(0, 0, -1, false)) do
    for _ in line:gmatch(escaped) do
      count = count + 1
    end
  end

  return count
end

--- Update the floating window title with current input and occurrence count
--- @param win number Window handle
--- @param original string Original word being replaced
--- @param new_text string New replacement text
--- @param count number Number of occurrences
local function update_window_title(win, original, new_text, count)
  if not api.nvim_win_is_valid(win) then
    return
  end

  local title
  if #new_text == 0 then
    title = string.format(' Replace: %s [%d occurrences] ', original, count)
  else
    title = string.format(' %s → %s [%d] ', original, new_text, count)
  end

  api.nvim_win_set_config(win, {
    title = { { title, 'FloatTitle' } },
    title_pos = 'center',
  })
end

--- Replace word under cursor with modern floating window UI
M.replace_word_under_cursor = function()
  local word = vim.fn.expand '<cword>'

  if not word or #word == 0 then
    vim.notify('No word under cursor', vim.log.levels.WARN)
    return
  end

  local count = count_occurrences(word)

  if count == 0 then
    vim.notify('Word not found in buffer', vim.log.levels.INFO)
    return
  end

  -- Save cursor position to restore later
  local original_pos = api.nvim_win_get_cursor(0)

  -- Create floating buffer
  local buf = api.nvim_create_buf(false, true)

  -- Calculate window width based on word length
  local width = math.max(30, #word + 20)

  -- Window configuration
  local winopts = {
    relative = 'cursor',
    width = width,
    height = 1,
    row = 1,
    col = 1,
    style = 'minimal',
    border = 'rounded',
    title = { { string.format(' Replace: %s [%d occurrences] ', word, count), 'FloatTitle' } },
    title_pos = 'center',
  }

  -- Open floating window
  local win = api.nvim_open_win(buf, true, winopts)

  -- Set window highlights
  vim.wo[win].winhl = 'Normal:Normal,FloatBorder:FloatBorder,CursorLine:Visual'
  vim.wo[win].cursorline = true

  -- Set up prompt buffer
  api.nvim_buf_set_lines(buf, 0, -1, true, { word })
  vim.bo[buf].buftype = 'prompt'
  vim.fn.prompt_setprompt(buf, '')

  -- Move cursor to end of input
  vim.api.nvim_input 'A'

  -- Create namespace for virtual text preview
  local ns_id = api.nvim_create_namespace 'replace_preview'

  -- Update title on text change
  api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
    buffer = buf,
    callback = function()
      local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
      local new_text = lines[1] or ''
      update_window_title(win, word, new_text, count)
    end,
  })

  -- Cancel with Escape
  vim.keymap.set({ 'i', 'n' }, '<Esc>', function()
    api.nvim_buf_delete(buf, { force = true })
    vim.notify('Replace cancelled', vim.log.levels.INFO)
  end, { buffer = buf, desc = 'Cancel replace' })

  -- Confirm with Enter
  vim.fn.prompt_setcallback(buf, function(text)
    api.nvim_buf_delete(buf, { force = true })

    local new_word = vim.trim(text)

    -- Only proceed if input is not empty and different from original
    if #new_word > 0 and new_word ~= word then
      local escaped_word = M.escape_pattern(word)
      local escaped_new = new_word:gsub('\\', '\\\\')

      -- Perform replacement
      local success, err = pcall(function()
        vim.cmd(string.format('%%s/%s/%s/g', escaped_word, escaped_new))
      end)

      if success then
        vim.notify(string.format("Replaced %d occurrence(s) of '%s' with '%s'", count, word, new_word), vim.log.levels.INFO)
        -- Restore cursor position
        api.nvim_win_set_cursor(0, original_pos)
      else
        vim.notify('Replace failed: ' .. tostring(err), vim.log.levels.ERROR)
      end
    else
      vim.notify('Replace cancelled', vim.log.levels.INFO)
    end
  end)

  -- Cleanup autocmd when buffer is deleted
  api.nvim_create_autocmd('BufWipeout', {
    buffer = buf,
    callback = function()
      api.nvim_buf_clear_namespace(0, ns_id, 0, -1)
    end,
  })
end

return M
