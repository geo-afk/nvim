local M = {}

-- Configuration
M.config = {
  width_ratio = 0.35,
  height_ratio = 0.35,
  border = 'rounded',
}

-- Setup highlight groups
local function setup_highlights()
  local highlights = {
    FilePickerBorder = { link = 'FloatBorder' },
    FilePickerTitle = { link = 'FloatTitle' },
    FilePickerNormal = { link = 'NormalFloat' },
    FilePickerSelected = { fg = '#88C0D0', bg = '#3B4252', bold = true },
    FilePickerDirectory = { fg = '#81A1C1' },
    FilePickerFile = { fg = '#D8DEE9' },
    FilePickerPrompt = { fg = '#A3BE8C', bold = true },
    FilePickerLineNr = { fg = '#616E88' },
  }

  for group, opts in pairs(highlights) do
    vim.api.nvim_set_hl(0, group, opts)
  end
end

-- Initialize highlights
setup_highlights()

local function telescope_available()
  return pcall(require, 'telescope')
end

-- Native floating window file picker
local function create_file_picker(files, opts, callback)
  local ui = vim.api.nvim_list_uis()[1]
  local width = math.floor(ui.width * M.config.width_ratio)
  local height = math.floor(ui.height * M.config.height_ratio)

  -- Create buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(buf, 'filetype', 'filepicker')

  -- Window options
  local win_opts = {
    relative = 'editor',
    width = width,
    height = height,
    col = math.floor((ui.width - width) / 2),
    row = math.floor((ui.height - height) / 2),
    style = 'minimal',
    border = M.config.border,
    title = ' ' .. (opts.prompt_title or 'Select File') .. ' ',
    title_pos = 'center',
  }

  local win = vim.api.nvim_open_win(buf, true, win_opts)

  -- Set window highlights
  vim.api.nvim_win_set_option(win, 'winhl', 'Normal:FilePickerNormal,FloatBorder:FilePickerBorder,FloatTitle:FilePickerTitle')
  vim.api.nvim_win_set_option(win, 'cursorline', true)

  -- Format file list
  local display_items = {}
  for i, file in ipairs(files) do
    local relative = vim.fn.fnamemodify(file, ':~:.')
    local is_dir = vim.fn.isdirectory(file) == 1
    display_items[i] = relative
  end

  -- Set buffer content
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, display_items)
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)

  -- Add line numbers with custom highlight
  vim.api.nvim_win_set_option(win, 'number', true)
  vim.api.nvim_win_set_option(win, 'relativenumber', false)
  vim.api.nvim_win_set_option(
    win,
    'winhl',
    'Normal:FilePickerNormal,FloatBorder:FilePickerBorder,FloatTitle:FilePickerTitle,CursorLine:FilePickerSelected,LineNr:FilePickerLineNr'
  )

  -- Apply syntax highlighting for files
  local ns_id = vim.api.nvim_create_namespace 'filepicker'
  for i, file in ipairs(files) do
    local is_dir = vim.fn.isdirectory(file) == 1
    local hl_group = is_dir and 'FilePickerDirectory' or 'FilePickerFile'
    vim.api.nvim_buf_add_highlight(buf, ns_id, hl_group, i - 1, 0, -1)
  end

  -- Helper function to close window
  local function close_window()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  -- Helper function to select item
  local function select_item()
    local line = vim.api.nvim_win_get_cursor(win)[1]
    local selected_file = files[line]
    close_window()

    if selected_file then
      local full_path = vim.fn.fnamemodify(selected_file, ':p')
      callback(full_path)
    end
  end

  -- Keymaps
  local keymaps = {
    ['<CR>'] = select_item,
    ['<Esc>'] = close_window,
    ['q'] = close_window,
    ['<C-c>'] = close_window,
  }

  for key, func in pairs(keymaps) do
    vim.api.nvim_buf_set_keymap(buf, 'n', key, '', {
      nowait = true,
      noremap = true,
      silent = true,
      callback = func,
    })
  end

  -- Auto-close on buffer leave
  vim.api.nvim_create_autocmd('BufLeave', {
    buffer = buf,
    once = true,
    callback = close_window,
  })
end

---Select a file and return its path via callback
---@param opts table|nil Options: prompt_title, cwd, width_ratio, height_ratio
---@param callback fun(path: string|nil)
function M.select_file(opts, callback)
  opts = opts or {}

  -- Override default config if specified
  local width_ratio = opts.width_ratio or M.config.width_ratio
  local height_ratio = opts.height_ratio or M.config.height_ratio

  if telescope_available() then
    local pickers = require 'telescope.pickers'
    local finders = require 'telescope.finders'
    local conf = require('telescope.config').values
    local actions = require 'telescope.actions'
    local action_state = require 'telescope.actions.state'

    -- Configure telescope window size
    local telescope_opts = vim.tbl_deep_extend('force', opts, {
      layout_strategy = 'center',
      layout_config = {
        width = width_ratio,
        height = height_ratio,
      },
    })

    pickers
      .new(telescope_opts, {
        prompt_title = opts.prompt_title or 'Select File',
        finder = finders.new_oneshot_job({ 'fd', '--type', 'f' }, { cwd = opts.cwd }),
        sorter = conf.generic_sorter(telescope_opts),
        attach_mappings = function(prompt_bufnr, map)
          local function select_file()
            local selection = action_state.get_selected_entry()
            actions.close(prompt_bufnr)

            if selection and selection.value then
              -- Get the path and convert to absolute path
              local path = selection.path or selection.value or selection[1]
              local full_path = vim.fn.fnamemodify(path, ':p')
              callback(full_path)
            else
              callback(nil)
            end
          end

          map('i', '<CR>', select_file)
          map('n', '<CR>', select_file)
          return true
        end,
      })
      :find()
    return
  end

  -- Fallback: Custom native file picker
  local cwd = opts.cwd or vim.fn.getcwd()
  local files = vim.fn.globpath(cwd, '**/*', true, true)

  -- Filter out directories
  files = vim.tbl_filter(function(path)
    return vim.fn.isdirectory(path) == 0
  end, files)

  if #files == 0 then
    vim.notify('No files found', vim.log.levels.WARN)
    callback(nil)
    return
  end

  -- Store original config and apply opts
  local original_width = M.config.width_ratio
  local original_height = M.config.height_ratio
  M.config.width_ratio = width_ratio
  M.config.height_ratio = height_ratio

  create_file_picker(files, opts, function(path)
    -- Restore original config
    M.config.width_ratio = original_width
    M.config.height_ratio = original_height
    callback(path)
  end)
end

-- Setup function for customization
function M.setup(user_config)
  M.config = vim.tbl_deep_extend('force', M.config, user_config or {})
  setup_highlights()
end

return M
