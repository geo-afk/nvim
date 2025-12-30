local M = {}

-- Default configuration
local config = {
  width_ratio = 0.7,
  height_ratio = 0.9,
  border = 'rounded',
  title = 'Terminal',
  title_pos = 'center',
  zindex = 50,
}

-- Create centered floating window
local function create_window()
  local maxh = vim.o.lines - vim.o.cmdheight - 1
  local maxw = vim.o.columns

  local height = math.floor(maxh * config.height_ratio)
  local width = math.floor(maxw * config.width_ratio)

  local row = math.floor((maxh - height) / 2)
  local col = math.floor((maxw - width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = 'wipe' -- safe to set here

  -- Do NOT set buftype = 'terminal' here!

  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    border = config.border,
    title = config.title,
    title_pos = config.title_pos,
    zindex = config.zindex,
    style = 'minimal',
  })

  -- Window-local options
  vim.wo[win].winhighlight = 'Normal:NormalFloat,FloatBorder:FloatBorder'
  vim.wo[win].wrap = false
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].cursorline = false
  vim.wo[win].signcolumn = 'no'

  return buf, win
end

-- Create terminal in floating window
function M.create_terminal(cmd)
  local buf, win = create_window()

  -- Start terminal job
  local job_id = vim.api.nvim_buf_call(buf, function()
    return vim.fn.termopen(cmd or 'nu', {
      on_exit = function()
        -- Auto-close when shell exits
        if vim.api.nvim_win_is_valid(win) then
          vim.api.nvim_win_close(win, true)
        end
      end,
    })
  end)

  vim.cmd 'startinsert'

  -- Buffer-local keymaps
  -- Normal mode: quick quit with q
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

  -- <Esc> in terminal mode → normal mode
  -- <Esc> in normal mode → close window
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

  -- Prevent 'q' from being typed into the terminal in insert/terminal mode
  vim.keymap.set('t', 'q', '<q>', { buffer = buf, noremap = true })
end

-- Setup function
function M.setup(user_config)
  config = vim.tbl_deep_extend('force', config, user_config or {})
end

return M
