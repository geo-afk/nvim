--- @class menu
local Menu = {}

--- Constructor
function Menu:new(get_items, format, actions, opts)
  local default_opts = {
    title = 'Menu',
    border = 'rounded',
    legend = { include = true, style = 'horizontal' },
    resize = { horizontal = false, vertical = false },
    position = 'center',
    win_opts = {
      style = 'minimal',
      noautocmd = true,
    },
    highlight = {
      border = 'FloatBorder',
      normal = 'NormalFloat',
      key = 'Constant',
      desc = 'Comment',
    },
  }

  opts = vim.tbl_deep_extend('force', default_opts, opts or {})

  local menu = {
    actions = actions,
    format = format,
    get_items = get_items,
    opts = opts,
  }

  menu.string_items = vim.tbl_map(function(item)
    return format(item)
  end, get_items())

  menu.buf = Menu.create_buffer()
  menu.namespace = vim.api.nvim_create_namespace 'menu'

  -- Build legend
  menu.legend = {}
  menu.legend_size = 0
  if opts.legend.include then
    for key, action in pairs(actions) do
      local text = ('[%s] %s'):format(key, action.desc)
      table.insert(menu.legend, text)
      menu.legend_size = math.max(menu.legend_size, #text)
    end
  end

  self.__index = self
  return setmetatable(menu, self)
end

function Menu.create_buffer()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = false
  vim.keymap.set('n', 'q', '<cmd>close!<CR>', { buffer = buf, silent = true })
  return buf
end

function Menu:render_buffer()
  vim.bo[self.buf].modifiable = true

  local lines = {}
  for _, item in ipairs(self.string_items) do
    table.insert(lines, '  ' .. item)
  end
  table.insert(lines, '')
  if not vim.tbl_isempty(self.legend) then
    table.insert(lines, '──────────  Actions ─────────────')
    table.insert(lines, table.concat(self.legend, '    '))
  end

  vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, lines)
  vim.bo[self.buf].modifiable = false
end

function Menu:create_window()
  local width = 0
  for _, str in ipairs(self.string_items) do
    width = math.max(width, #str)
  end
  width = width + 8
  local height = #self.string_items + (self.opts.legend.include and 3 or 1)

  local row, col, relative = 0, 0, 'editor'
  local pos = self.opts.position

  if pos == 'center' then
    relative = 'editor'
    row = math.ceil((vim.o.lines - height) / 2)
    col = math.ceil((vim.o.columns - width) / 2)
  elseif pos == 'cursor' then
    relative = 'win'
    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    row = cursor_pos[1]
    col = cursor_pos[2]
  elseif pos == 'mouse' then
    relative = 'editor'
    local mp = vim.fn.getmousepos()
    row = math.max(0, mp.screenrow - 1)
    col = math.max(0, mp.screencol)
    -- keep inside screen bounds
    if col + width > vim.o.columns then
      col = vim.o.columns - width
    end
    if row + height > vim.o.lines then
      row = vim.o.lines - height
    end
  elseif type(pos) == 'table' then
    -- If explicit coordinates given, use buffer-relative positioning if possible
    relative = 'win'
    row = pos.row or 0
    col = pos.col or 0
  end

  -- fallback just in case
  row = row or 0
  col = col or 0

  local win_opts = vim.tbl_deep_extend('force', {
    relative = relative,
    width = width,
    height = height,
    row = row,
    col = col,
    border = self.opts.border,
    title = self.opts.title,
    title_pos = 'center',
    style = self.opts.win_opts.style,
  }, self.opts.win_opts)

  self.win = vim.api.nvim_open_win(self.buf, true, win_opts)
  vim.wo[self.win].winhighlight = string.format('Normal:%s,FloatBorder:%s', self.opts.highlight.normal, self.opts.highlight.border)
end

function Menu:set_keymaps()
  for key, action in pairs(self.actions) do
    vim.keymap.set('n', key, function()
      local line = vim.api.nvim_win_get_cursor(0)[1]
      local current_item = self.get_items()[line]
      action.fn(current_item)
      if action.close then
        vim.api.nvim_win_close(self.win, true)
      elseif action.update then
        self.string_items = vim.tbl_map(self.format, self.get_items())
        self:render_buffer()
      end
    end, { buffer = self.buf, silent = true, nowait = true })
  end
end

function Menu:__call()
  if vim.tbl_isempty(self.string_items) then
    vim.notify('No items to display in the menu', vim.log.levels.WARN)
    return
  end
  self:set_keymaps()
  self:render_buffer()
  self:create_window()
end

return Menu
