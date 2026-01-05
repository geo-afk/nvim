local M = {}

-- Default configuration
local config = {
  width_ratio = 0.7,
  height_ratio = 0.9,
  border = 'rounded',
  title = 'Terminal',
  title_pos = 'center',
  zindex = 50,
  transparent = false, -- New option
  winblend = 0, -- 0 = opaque, 100 = fully transparent
}

-- Set up custom highlight groups
local function setup_highlights()
  -- Title background with better contrast
  vim.api.nvim_set_hl(0, 'FloatTermTitle', {
    bg = '#7aa2f7',
    fg = '#1a1b26',
    bold = true,
  })

  -- Border with subtle color
  vim.api.nvim_set_hl(0, 'FloatTermBorder', {
    fg = '#7aa2f7',
  })

  -- Terminal background - can be transparent
  if config.transparent then
    vim.api.nvim_set_hl(0, 'FloatTermNormal', {
      bg = 'NONE', -- Transparent background
    })
  else
    vim.api.nvim_set_hl(0, 'FloatTermNormal', {
      bg = '#16161e',
    })
  end
end

-- Initialize highlights
setup_highlights()

-- Detect OS and get appropriate shell command wrapper
local function get_shell_cmd(cmd)
  if type(cmd) == 'table' then
    return cmd
  end

  local is_windows = vim.fn.has 'win32' == 1 or vim.fn.has 'win64' == 1

  if is_windows then
    if vim.fn.executable 'pwsh' == 1 then
      return { 'pwsh', '-NoLogo', '-NoProfile', '-Command', cmd }
    elseif vim.fn.executable 'powershell' == 1 then
      return { 'powershell', '-NoLogo', '-NoProfile', '-Command', cmd }
    else
      return { 'cmd', '/c', cmd }
    end
  else
    local shell = vim.o.shell
    if shell and shell ~= '' then
      return { shell, '-c', cmd }
    else
      return { 'sh', '-c', cmd }
    end
  end
end

-- Create centered floating window with enhanced UI
local function create_window(title)
  local maxh = vim.o.lines - vim.o.cmdheight - 1
  local maxw = vim.o.columns
  local height = math.floor(maxh * config.height_ratio)
  local width = math.floor(maxw * config.width_ratio)
  local row = math.floor((maxh - height) / 2)
  local col = math.floor((maxw - width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = 'wipe'

  local padded_title = ' ' .. (title or config.title) .. ' '

  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    border = config.border,
    title = padded_title,
    title_pos = config.title_pos,
    zindex = config.zindex,
    style = 'minimal',
  })

  -- Apply transparency if enabled
  if config.winblend > 0 then
    vim.wo[win].winblend = config.winblend
  end

  -- Apply custom highlights
  vim.wo[win].winhighlight = 'Normal:FloatTermNormal,FloatBorder:FloatTermBorder,FloatTitle:FloatTermTitle'
  vim.wo[win].wrap = false
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].cursorline = false
  vim.wo[win].signcolumn = 'no'

  return buf, win
end

-- Create terminal in floating window
function M.create_terminal(cmd, opts)
  opts = opts or {}
  local title = opts.title or (type(cmd) == 'string' and cmd or nil) or config.title
  local buf, win = create_window(title)

  local shell_cmd = get_shell_cmd(cmd)

  local job_id = vim.api.nvim_buf_call(buf, function()
    return vim.fn.jobstart(shell_cmd, {
      term = true,
      on_exit = function(_, exit_code, _)
        if vim.api.nvim_buf_is_valid(buf) then
          vim.bo[buf].modifiable = true

          local exit_msg
          if exit_code == 0 then
            exit_msg = '✓ Process completed successfully. Press q or <Esc> to close'
          else
            exit_msg = string.format('✗ Process exited with code %d. Press q or <Esc> to close', exit_code)
          end

          vim.api.nvim_buf_set_lines(buf, -1, -1, false, {
            '',
            string.rep('─', 80),
            exit_msg,
          })
          vim.bo[buf].modifiable = false
        end
      end,
    })
  end)

  vim.cmd 'startinsert'

  vim.keymap.set('n', 'q', function()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end, {
    buffer = buf,
    nowait = true,
    silent = true,
    desc = 'Close floating terminal',
  })

  vim.keymap.set({ 't', 'n' }, '<Esc>', function()
    local mode = vim.api.nvim_get_mode().mode
    if mode == 'n' then
      vim.api.nvim_win_close(win, true)
    else
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<C-\\><C-n>', true, true, true), 'n', true)
    end
  end, {
    buffer = buf,
    nowait = true,
    silent = true,
    desc = 'Exit terminal or close window',
  })

  vim.keymap.set('t', 'q', 'q', { buffer = buf, noremap = true })

  return job_id, buf, win
end

-- Setup function
function M.setup(user_config)
  config = vim.tbl_deep_extend('force', config, user_config or {})

  -- Reapply highlights after config change
  setup_highlights()

  -- Allow custom colors
  if user_config and user_config.colors then
    if user_config.colors.title_bg then
      vim.api.nvim_set_hl(0, 'FloatTermTitle', {
        bg = user_config.colors.title_bg,
        fg = user_config.colors.title_fg or '#1a1b26',
        bold = true,
      })
    end
    if user_config.colors.border then
      vim.api.nvim_set_hl(0, 'FloatTermBorder', {
        fg = user_config.colors.border,
      })
    end
    if user_config.colors.background and not config.transparent then
      vim.api.nvim_set_hl(0, 'FloatTermNormal', {
        bg = user_config.colors.background,
      })
    end
  end
end

return M
