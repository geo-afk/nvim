local states = require('custom.ui.tabline_states').tabline_states
local utils = require 'custom.ui.utils'

local api = vim.api
local fn = vim.fn
local nvim_buf_get_name = api.nvim_buf_get_name
local nvim_get_option_value = api.nvim_get_option_value
local nvim_list_bufs = api.nvim_list_bufs
local nvim_strwidth = api.nvim_strwidth
local nvim_eval_statusline = api.nvim_eval_statusline
local nvim_get_current_buf = api.nvim_get_current_buf
local nvim_buf_delete = api.nvim_buf_delete
local nvim_get_mode = api.nvim_get_mode
local timer_fn = utils.timer_fn
local generate_highlight = utils.generate_highlight
local find_index = utils.find_index
local fnamemodify = fn.fnamemodify
local schedule = vim.schedule

-- Try to load nvim-web-devicons, fallback to mini.icons
local has_webdevicons, webdevicons = pcall(require, 'nvim-web-devicons')
local has_miniicons, miniicons = pcall(require, 'mini.icons')

-- Determine which icon provider to use
local icon_provider = nil
if has_webdevicons then
  icon_provider = 'webdevicons'
  states.has_webdevicons = true
elseif has_miniicons then
  icon_provider = 'miniicons'
  states.has_webdevicons = true -- Keep for backwards compatibility
else
  icon_provider = 'none'
  states.has_webdevicons = false
end

local nvim_get_current_tabpage = api.nvim_get_current_tabpage
local nvim_list_tabpages = api.nvim_list_tabpages
local isdirectory = fn.isdirectory

local M = {}

---Checks if a buffer is valid for display in the tabline.
---@param bufnr integer The buffer number to check.
---@return boolean True if the buffer is valid, false otherwise.
local function buf_is_valid(bufnr)
  local hide_misc = states.active_config.hide_misc_buffers
  local listed = nvim_get_option_value('buflisted', { buf = bufnr })
  if hide_misc then
    local bufname = nvim_buf_get_name(bufnr)
    return listed and isdirectory(bufname) == 0 and bufname ~= ''
  end
  return listed
end

---Filters a list of buffer numbers, returning only the valid ones.
---@param buffers integer[] A table of buffer numbers.
---@return integer[] A table of valid buffer numbers.
local function get_tabline_buffers_list(buffers)
  local buf_list = {}
  for _, i in ipairs(buffers) do
    if buf_is_valid(i) then
      table.insert(buf_list, i)
      states.buffer_map[i] = i
    end
  end
  return buf_list
end

---Generates tabline highlight groups.
---@param source string The source highlight group.
---@param state integer The buffer state.
---@param opts table Options for the highlight.
---@param new_name string|nil The new highlight group name.
---@return string The highlight group name.
local function generate_tabline_highlight(source, state, opts, new_name)
  if states.cache.highlights[new_name] then
    return new_name
  end
  local suffix, prefix, brightness_bg, brightness_fg
  if state == states.BufferStates.ACTIVE then
    suffix, prefix, brightness_bg, brightness_fg = 'Active', 'TabLine', 10, 0
  elseif state == states.BufferStates.INACTIVE then
    suffix, prefix, brightness_bg, brightness_fg = 'Inactive', 'TabLine', 5, -25
  elseif state == states.BufferStates.NONE then
    suffix, prefix, brightness_bg, brightness_fg = 'None', 'TabLine', 0, -25
  elseif state == states.BufferStates.MISC then
    suffix, prefix, brightness_bg, brightness_fg = 'None', 'TabLine', 6, 0
  end
  return generate_highlight(source, 'TabLineFill', opts, brightness_bg, brightness_fg, prefix, suffix, new_name)
end

---Gets the buffer state.
---@param bufnr integer The buffer number.
---@return integer The buffer state.
local function get_buffer_state(bufnr)
  if bufnr == nvim_get_current_buf() then
    return states.BufferStates.ACTIVE
  elseif states.buffer_map[bufnr] then
    return states.BufferStates.INACTIVE
  end
  return states.BufferStates.NONE
end

---Processes the buffer name for display.
---@param bufnr integer The buffer number.
---@return string The processed buffer name.
local function process_buffer_name(bufnr)
  local buf_path = nvim_buf_get_name(bufnr)
  local bufname_short = fnamemodify(buf_path, ':t')
  local init_files = states.init_files or { 'init.lua' }

  if init_files[bufname_short] or states.duplicate_buf_names[bufname_short] then
    return string.format('%s%s%s', fnamemodify(buf_path, ':h:t'), '/', bufname_short)
  end
  return bufname_short
end

---Gets left and right padding.
---@param buf_string string The buffer string.
---@return string, string The left and right padding strings.
local function get_lr_padding(buf_string)
  local width = states.tabline_buf_str_max_width
  local padding = width - #buf_string
  local left_padding, right_padding = 2, 2

  if padding <= 3 then
    right_padding = math.floor(padding / 2)
    left_padding = padding - right_padding
  end

  return string.rep(' ', left_padding), string.rep(' ', right_padding)
end

---Gets file icon and highlight using the appropriate icon provider.
---@param bufnr integer The buffer number.
---@return string icon The file icon.
---@return string hl The highlight group name.
local function get_file_icon(bufnr)
  local buf_path = nvim_buf_get_name(bufnr)
  local filename = fnamemodify(buf_path, ':t')
  local extension = fnamemodify(buf_path, ':e')
  local filetype = nvim_get_option_value('filetype', { buf = bufnr })

  -- Create a cache key based on filetype (most specific), then extension, then filename
  local cache_key = filetype ~= '' and filetype or (extension ~= '' and extension or filename)

  -- Check cache first
  if states.cache.fileicons[cache_key] then
    return states.cache.fileicons[cache_key].icon, states.cache.fileicons[cache_key].hl
  end

  local icon, hl = '', 'TabLineFill'

  if icon_provider == 'webdevicons' then
    -- Try by filename first (more specific)
    if filename ~= '' then
      icon, hl = webdevicons.get_icon(filename, extension, { default = false })
    end

    -- Fallback to filetype
    if not icon and filetype ~= '' then
      icon, hl = webdevicons.get_icon_by_filetype(filetype, { default = false })
    end

    -- Final fallback to default icon
    if not icon then
      icon, hl = webdevicons.get_icon(filename, extension, { default = true })
    end
  elseif icon_provider == 'miniicons' then
    -- MiniIcons approach
    if filetype ~= '' then
      icon, hl = miniicons.get('filetype', filetype)
    else
      icon, hl = miniicons.get('file', filename)
    end
  end

  -- Ensure we have valid values
  icon = icon or ''
  hl = hl or 'TabLineFill'

  -- Cache the result
  states.cache.fileicons[cache_key] = { icon = icon, hl = hl }

  return icon, hl
end

---Gets the close button string.
---@param bufnr integer The buffer number.
---@return string The formatted close button string.
local function get_close_button(bufnr)
  -- Check if in jump mode and close button is already set
  if states.buffers_spec[bufnr] and states.jump_mode_enabled then
    if states.buffers_spec[bufnr].close_btn then
      return states.buffers_spec[bufnr].close_btn
    end
  end

  local close_button_str = '%%%d@v:lua.tabline_close_button_callback@%%#%s#%s%%X'
  local close_btn_inactive_hl = generate_tabline_highlight('PreProc', states.BufferStates.INACTIVE, {}, 'TabLineCloseButtonInactive')

  local mode = nvim_get_mode().mode
  local is_current = bufnr == nvim_get_current_buf()
  local is_modified = nvim_get_option_value('modified', { buf = bufnr })

  -- Insert mode indicator (active buffer only)
  if mode == 'i' and is_current then
    local close_btn_insert_mode_hl = generate_tabline_highlight('String', states.BufferStates.ACTIVE, {}, 'TabLineDotActive')
    return string.format(close_button_str, bufnr, close_btn_insert_mode_hl, states.icons.active_dot)
  end

  -- Modified indicator (active buffer)
  if is_modified and is_current then
    local close_btn_modified_hl = generate_tabline_highlight('Constant', states.BufferStates.ACTIVE, {}, 'TabLineModifiedActive')
    return string.format(close_button_str, bufnr, close_btn_modified_hl, states.icons.active_dot)
  end

  -- Modified indicator (inactive buffer)
  if is_modified then
    local close_btn_modified_hl = generate_tabline_highlight('Constant', states.BufferStates.MISC, {}, 'TabLineModifiedInactive')
    return string.format(close_button_str, bufnr, close_btn_modified_hl, states.icons.active_dot)
  end

  -- Normal close button (active buffer)
  if is_current then
    local close_btn_active_hl = generate_tabline_highlight('PreProc', states.BufferStates.ACTIVE, {}, 'TabLineCloseButtonActive')
    return string.format(close_button_str, bufnr, close_btn_active_hl, states.icons.close)
  end

  -- Normal close button (inactive buffer)
  return string.format(close_button_str, bufnr, close_btn_inactive_hl, states.icons.close)
end

---Global callback for buffer clicks.
---@param bufnr integer The buffer number.
_G.tabline_click_buffer_callback = function(bufnr)
  if not buf_is_valid(bufnr) and nvim_get_option_value('buflisted', { buf = bufnr }) then
    return
  end
  vim.cmd(string.format('buffer %s', bufnr))
end

---Gets buffer information.
---@param bufnr integer The buffer number.
---@return table|nil Buffer information table.
local function get_buffer_info(bufnr)
  local buf_name = process_buffer_name(bufnr)
  local state = get_buffer_state(bufnr)
  local icon, icon_hl = get_file_icon(bufnr)

  -- Add space after icon
  icon = icon .. ' '
  icon_hl = generate_tabline_highlight(icon_hl, state, {}, nil)

  local left_padding, right_padding = get_lr_padding(buf_name)

  -- Calculate total length
  local length = nvim_strwidth(buf_name)
    + nvim_strwidth(states.icons.separator)
    + nvim_strwidth(icon)
    + nvim_strwidth(left_padding)
    + nvim_strwidth(right_padding)
    + nvim_strwidth(states.icons.close)

  local close_btn = get_close_button(bufnr)

  return {
    buf_name = buf_name,
    padding_length = #left_padding + #right_padding,
    icon_hl = icon_hl,
    icon = icon,
    length = length,
    state = state,
    left_padding = left_padding,
    right_padding = right_padding,
    close_btn = close_btn,
  }
end

M.buf_is_valid = buf_is_valid
M.get_buffer_info = get_buffer_info

---Gets valid buffers with their specifications.
---@param bufs integer[] List of buffer numbers.
---@return table Buffer specifications.
local function get_buffers_with_specs(bufs)
  local bufs_spec = {}
  for _, i in ipairs(bufs) do
    local info = get_buffer_info(i)
    if info then
      bufs_spec[i] = info
    end
  end
  return bufs_spec
end

---Calculates the space occupied by buffers.
---@param bufs integer[] List of buffer numbers.
---@return integer Total space occupied.
local function calculate_buf_space(bufs)
  local length = 0
  for _, bufnr in ipairs(bufs) do
    if states.buffers_spec[bufnr] and states.buffers_spec[bufnr].length then
      length = length + states.buffers_spec[bufnr].length
    else
      -- Fallback: calculate on the fly if not cached
      local buf_info = get_buffer_info(bufnr)
      if buf_info then
        length = length + buf_info.length
      end
    end
  end
  return length
end

---Updates overflow indicators for the tabline.
M.update_overflow_info = function()
  local bufs = states.buffers_list
  local left_dist = states.start_idx - 1
  local right_dist = #bufs - states.end_idx

  states.left_overflow_str = ''
  states.right_overflow_str = ''
  states.left_overflow_idicator_length = 0
  states.right_overflow_idicator_length = 0

  if left_dist > 0 then
    states.left_overflow_str =
      string.format('%s%s%s %d %%* ', '%#TabLineOverflowIndicator#', states.icons.left_overflow_indicator, '%#TabLineOverflowCount#', left_dist)
    states.left_overflow_idicator_length = nvim_eval_statusline(states.left_overflow_str, { use_tabline = true }).width
  end

  if right_dist > 0 then
    states.right_overflow_str =
      string.format(' %s %d %s%s%%*', '%#TabLineOverflowCount#', right_dist, '%#TabLineOverflowIndicator#', states.icons.right_overflow_indicator)
    states.right_overflow_idicator_length = nvim_eval_statusline(states.right_overflow_str, { use_tabline = true }).width
  end
end

M.calculate_buf_space = calculate_buf_space

---Fetches visible buffers based on available space.
---@param bufnr integer The current buffer number.
---@param bufs integer[] List of all buffers.
---@param buf_specs table Buffer specifications.
local function fetch_visible_buffers(bufnr, bufs, buf_specs)
  local columns = nvim_get_option_value('columns', {})
  local available_space = columns - (states.left_overflow_idicator_length + states.right_overflow_idicator_length + states.tabpages_str_length)
  local buf_space = calculate_buf_space(bufs)

  states.visible_buffers = bufs
  states.start_idx = 1
  states.end_idx = #states.visible_buffers
  states.available_space = available_space

  -- If all buffers fit, return early
  if buf_space <= available_space then
    return
  end

  -- Find current buffer index
  local current_buf_index = find_index(bufs, bufnr)
  if not current_buf_index then
    return
  end

  -- Start with current buffer
  local visible_buffers = { bufnr }
  local occupied_space = buf_specs[bufnr].length
  local left_idx = current_buf_index - 1
  local right_idx = current_buf_index + 1
  local left_space = 0
  local right_space = 0

  -- Expand left and right alternately to fill available space
  while occupied_space <= available_space do
    local left_buf = bufs[left_idx]
    local right_buf = bufs[right_idx]
    local left_len = left_buf and buf_specs[left_buf].length or 0
    local right_len = right_buf and buf_specs[right_buf].length or 0

    local can_add_left = left_len > 0 and (occupied_space + left_len <= available_space)
    local can_add_right = right_len > 0 and (occupied_space + right_len <= available_space)

    if can_add_left and (not can_add_right or left_space <= right_space) then
      table.insert(visible_buffers, 1, left_buf)
      left_space = left_space + left_len
      occupied_space = occupied_space + left_len
      left_idx = left_idx - 1
    elseif can_add_right then
      table.insert(visible_buffers, right_buf)
      right_space = right_space + right_len
      occupied_space = occupied_space + right_len
      right_idx = right_idx + 1
    else
      break
    end
  end

  states.occupied_space = occupied_space
  states.start_idx = find_index(bufs, visible_buffers[1])
  states.end_idx = find_index(bufs, visible_buffers[#visible_buffers])
  states.visible_buffers = visible_buffers
end

M.fetch_visible_buffers = fetch_visible_buffers

---Gets buffer highlight group.
---@param bufnr integer The buffer number.
---@return string The highlight group name.
local function get_buffer_highlight(bufnr)
  if nvim_get_current_buf() == bufnr then
    return generate_tabline_highlight('TabLineFill', states.BufferStates.ACTIVE, { italic = true, bold = true }, 'TabLineActive')
  end
  return generate_tabline_highlight('TabLineFill', states.BufferStates.INACTIVE, {}, 'TabLineInactive')
end

---Global callback for close button clicks.
---@param bufnr integer The buffer number.
_G.tabline_close_button_callback = function(bufnr)
  if not buf_is_valid(bufnr) and nvim_get_option_value('buflisted', { buf = bufnr }) then
    return
  end

  if nvim_get_option_value('modified', { buf = bufnr }) then
    local choice = vim.fn.confirm('This buffer has been modified! Save before closing?', '&Yes\n&No\n&Cancel', 3)
    if choice == 1 then
      vim.cmd 'silent! write'
    elseif choice == 3 then
      return -- Cancel
    end
  end

  schedule(function()
    -- Disable inlay hints before deleting the buffer
    pcall(vim.lsp.inlay_hint.enable, false, { bufnr = bufnr })

    -- Delete the buffer
    local ok = pcall(nvim_buf_delete, bufnr, { force = false })

    if ok then
      -- Update buffer list and specs
      states.buffers_list = get_tabline_buffers_list(nvim_list_bufs())
      states.buffers_spec = get_buffers_with_specs(states.buffers_list)
      local bufs = states.buffers_list
      local buf_specs = states.buffers_spec
      fetch_visible_buffers(nvim_get_current_buf(), bufs, buf_specs)
    end
  end)
end

---Generates the buffer string for the tabline.
---@param bufnr integer The buffer number.
---@return string The formatted buffer string.
local function generate_buffer_string(bufnr)
  local buf_spec = states.buffers_spec[bufnr] or get_buffer_info(bufnr)
  if not buf_spec then
    return ''
  end

  local buf_hl = get_buffer_highlight(bufnr)
  local left_padding, right_padding = buf_spec.left_padding, buf_spec.right_padding

  local buf_string = string.format(
    '%%%d@v:lua.tabline_click_buffer_callback@%%#%s#%s%s%s%%#%s#%s%s%%X%s%%*',
    bufnr,
    buf_spec.icon_hl,
    states.icons.separator,
    left_padding,
    buf_spec.icon,
    buf_hl,
    buf_spec.buf_name,
    right_padding,
    buf_spec.close_btn
  )
  return buf_string
end

---Updates the global tabline buffer string.
local function update_tabline_buffer_string()
  states.tabline_update_buffer_string_timer = timer_fn(states.tabline_update_buffer_string_timer, 50, function()
    states.timer_count = states.timer_count + 1
    local tabline_content = ''

    for _, bufnr in ipairs(states.visible_buffers) do
      tabline_content = tabline_content .. generate_buffer_string(bufnr)
    end

    states.cache.tabline_string =
      string.format('%s%s%s%s%s', states.left_overflow_str, tabline_content, states.right_overflow_str, '%#TabLineFill#%=', states.tabpages_str)
    vim.cmd 'redrawtabline'
  end)
end

---Navigate to previous buffer.
M.previous_buffer = function()
  if not vim.g.ui_tabline_enabled then
    vim.cmd 'bprevious'
    return
  end

  local bufs = states.buffers_list
  local buf = nvim_get_current_buf()
  local pos = find_index(bufs, buf)

  if not pos then
    return
  end

  pos = pos > 1 and pos - 1 or #bufs

  if bufs[pos] then
    vim.cmd(string.format('buffer %d', bufs[pos]))
  end
end

---Navigate to next buffer.
M.next_buffer = function()
  if not vim.g.ui_tabline_enabled then
    vim.cmd 'bnext'
    return
  end

  local bufs = states.buffers_list
  local buf = nvim_get_current_buf()
  local pos = find_index(bufs, buf)

  if not pos then
    return
  end

  pos = pos < #bufs and pos + 1 or 1

  if bufs[pos] then
    vim.cmd(string.format('buffer %d', bufs[pos]))
  end
end

---Close current buffer.
M.close_buffer = function()
  local current_buf = nvim_get_current_buf()
  _G.tabline_close_button_callback(current_buf)
end

---Set keymaps for tabline navigation.
M.set_keymaps = function()
  vim.keymap.set('n', '<S-Tab>', M.previous_buffer, { desc = 'Previous buffer' })
  vim.keymap.set('n', '<Tab>', M.next_buffer, { desc = 'Next buffer' })
  vim.keymap.set('n', '<leader>bj', M.jump_mode, { desc = 'Toggle Jump Mode' })
  vim.keymap.set('n', '<A-c>', M.close_buffer, { desc = 'Close buffer' })
end

---Initialize the tabline.
--- param opts table|nil Configuration options.
M.initialize_tabline = function(opts)
  states.active_config = vim.tbl_deep_extend('force', states.default_config, opts or {})
  M.set_keymaps()
  M.update_tabline_buffer_info()
  M.update_tabline_buffer_string()
end

---Get the current tabline string.
---@return string The tabline string.
M.get_tabline = function()
  return states.cache.tabline_string
end

---Get tabpage highlight based on state.
---@param tab integer The tabpage number.
---@return string, string, string Highlight groups and icon.
local function get_tabpage_hl(tab)
  local status_icon_active_hl = generate_tabline_highlight('TabLineTabPageActive', states.BufferStates.ACTIVE, { reverse = false }, 'TablineTabPageStatusIcon')
  local status_icon_inactive_hl =
    generate_tabline_highlight('TabLineTabPageActive', states.BufferStates.INACTIVE, { reverse = false }, 'TablineTabPageStatusIconInactive')
  local tabnr_inactive_hl = generate_tabline_highlight('TabLineTabPageActive', states.BufferStates.INACTIVE, { reverse = true }, 'TabLineTabPageInactive')

  if nvim_get_current_tabpage() == tab then
    return '%#TabLineTabPageActive#', string.format('%%#%s#', status_icon_active_hl), states.icons.tabpage_status_icon_active
  end

  return string.format('%%#%s#', tabnr_inactive_hl), string.format('%%#%s#', status_icon_inactive_hl), states.icons.tabpage_status_icon_inactive
end

---Update tabline string with tabpage information.
---@param tabs table List of tabpages.
M.update_tabline_string = function(tabs)
  local str = ''
  for idx, tab in ipairs(tabs) do
    local hl, close_hl, close_icon = get_tabpage_hl(tab)
    str = string.format('%s%%%d@v:lua.tabline_click_tabpage_callback@%s%%T %s %d %s', close_hl, idx, close_icon, hl, idx, str)
  end

  states.tabpages_str = string.format(' %s%%@v:lua.tabline_click_tabpage_icon_callback@ %s %%T%%* %s', '%#TabLineTabPageIcon#', states.icons.tabpage_icon, str)
end

---Global callback for tabpage clicks.
---@param tabnr integer The tabpage number.
---@param n_clicks integer Number of clicks.
---@param type string Click type ('l' for left, 'r' for right).
_G.tabline_click_tabpage_callback = function(tabnr, n_clicks, type)
  if type == 'r' then
    if #nvim_list_tabpages() <= 1 then
      vim.notify('Cannot close the last tabpage!', vim.log.levels.ERROR, { title = 'Invalid Tabpage Action' })
      return
    end
    vim.cmd(string.format('tabclose %d', tabnr))
  elseif type == 'l' and n_clicks == 2 then
    vim.cmd 'tabnew'
  elseif type == 'l' and n_clicks == 1 then
    vim.cmd(string.format('tabnext %s', tabnr))
  end
end

---Global callback for tabpage icon clicks.
_G.tabline_click_tabpage_icon_callback = function()
  vim.cmd 'tabnew'
end

---Update tabpage information.
M.tabline_update_tabpages_info = function()
  states.tabline_tabpage_timer = timer_fn(states.tabline_tabpage_timer, 50, function()
    states.timer_count = states.timer_count + 1
    local tabs = nvim_list_tabpages()
    M.update_tabline_string(tabs)
    states.tabpages_str_length = nvim_eval_statusline(states.tabpages_str, { use_tabline = true }).width
  end)
end

M.get_tabline_buffers_list = get_tabline_buffers_list
M.update_tabline_buffer_string = update_tabline_buffer_string
M.get_buffers_with_specs = get_buffers_with_specs
M.generate_buffer_string = generate_buffer_string

---Reset jump mode characters.
M.reset_jump_chars = function()
  for bufnr, spec in pairs(states.buffers_spec) do
    spec.close_btn = get_close_button(bufnr)
  end
  M.update_tabline_buffer_string()
  states.jump_mode_enabled = false
end

---Toggle jump mode characters.
M.toggle_jump_chars = function()
  states.jump_char_map = {}
  states.jump_mode_enabled = true

  -- Assign jump chars to visible buffers
  local char_idx = 1
  for _, buf in ipairs(states.visible_buffers) do
    if buf == nvim_get_current_buf() then
      goto continue
    end

    local jump_char = string.sub(states.active_config.jump_chars, char_idx, char_idx)
    if jump_char and jump_char ~= '' then
      states.jump_char_map[jump_char] = buf
      if states.buffers_spec[buf] then
        states.buffers_spec[buf].close_btn = string.format('%%#TabLineJumpChar#%s%s%s', ' ', jump_char, ' %*')
      end
      char_idx = char_idx + 1
    else
      break
    end
    ::continue::
  end

  M.update_tabline_buffer_string()
end

---Activate jump mode for quick buffer switching.
M.jump_mode = function()
  M.toggle_jump_chars()

  if #states.visible_buffers == 1 then
    M.reset_jump_chars()
    return
  end

  local char = vim.fn.getcharstr()
  local bufnr = states.jump_char_map[char]

  if bufnr then
    vim.cmd(string.format('buffer %d', bufnr))
  end

  M.reset_jump_chars()
end

---Update tabline buffer information.
M.update_tabline_buffer_info = function()
  states.tabline_update_buffer_info_timer = timer_fn(states.tabline_update_buffer_info_timer, 50, function()
    local current_bufnr = nvim_get_current_buf()

    -- If current buffer is not valid, try to find a valid buffer
    if not buf_is_valid(current_bufnr) then
      local bufs = get_tabline_buffers_list(nvim_list_bufs())
      local first_valid_buf = bufs[1]

      if not first_valid_buf then
        return
      end

      current_bufnr = first_valid_buf
    end

    states.timer_count = states.timer_count + 1
    states.buffers_list = get_tabline_buffers_list(nvim_list_bufs())

    -- Cache duplicate buffer names
    local bufnames_temp = {}
    states.duplicate_buf_names = {}

    for _, bufnr_iter in ipairs(states.buffers_list) do
      local buf_path = nvim_buf_get_name(bufnr_iter)
      local buf_name_short = fnamemodify(buf_path, ':t')

      if bufnames_temp[buf_name_short] then
        states.duplicate_buf_names[buf_name_short] = true
      else
        bufnames_temp[buf_name_short] = true
      end
    end

    states.buffers_spec = get_buffers_with_specs(states.buffers_list)

    -- Reset overflow indicators
    states.left_overflow_str = ''
    states.right_overflow_str = ''
    states.left_overflow_idicator_length = 0
    states.right_overflow_idicator_length = 0

    -- First pass: Determine visible buffers
    fetch_visible_buffers(current_bufnr, states.buffers_list, states.buffers_spec)

    -- Update overflow info
    M.update_overflow_info()

    -- Second pass: Recalculate if overflow indicators changed available space
    if states.left_overflow_idicator_length > 0 or states.right_overflow_idicator_length > 0 then
      fetch_visible_buffers(current_bufnr, states.buffers_list, states.buffers_spec)
      M.update_overflow_info()
    end
  end)
end

return M
