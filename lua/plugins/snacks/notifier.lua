local M = {}

function M.openNotif(idx)
  -- CONFIG
  local maxWidth = 0.75
  local maxHeight = 0.6
  local topPadding = 2 -- lines from top of screen

  -- get notification
  if idx == 'last' then
    idx = 1
  end

  local history = Snacks.notifier.get_history {
    filter = function(notif)
      return notif.level ~= 'trace'
    end,
    reverse = true,
  }

  if #history == 0 then
    local msg = 'No notifications yet.'
    vim.notify(msg, vim.log.levels.TRACE, { title = 'Last notification', icon = '󰎟' })
    return
  end

  local notif = assert(history[idx], 'Notification not found.')
  Snacks.notifier.hide(notif.id)

  -- win properties
  local bufnr = vim.api.nvim_create_buf(false, true)
  local lines = vim.split(notif.msg, '\n')
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  -- Calculate dimensions
  local height = math.min(#lines + 4, math.ceil(vim.o.lines * maxHeight))
  local longestLine = vim.iter(lines):fold(0, function(acc, line)
    return math.max(acc, vim.fn.strdisplaywidth(line))
  end)

  local title = vim.trim((notif.icon or '') .. ' ' .. (notif.title or ''))
  longestLine = math.max(longestLine, vim.fn.strdisplaywidth(title) + 4)
  local width = math.min(longestLine + 6, math.ceil(vim.o.columns * maxWidth))

  -- Calculate overflow and footer
  local overflow = #lines - (height - 4)
  local moreLines = overflow > 0 and ('  %d more lines'):format(overflow) or ''
  local indexStr = ('%d of %d'):format(idx, #history)
  local navHint = '  Tab/S-Tab to navigate'
  local footer = moreLines ~= '' and (indexStr .. moreLines .. navHint) or (indexStr .. navHint)

  -- Modern highlight groups
  local levelCapitalized = notif.level:sub(1, 1):upper() .. notif.level:sub(2)
  local highlights = {
    'Normal:SnacksNormal',
    'NormalNC:SnacksNormalNC',
    'FloatBorder:SnacksNotifierBorder' .. levelCapitalized,
    'FloatTitle:SnacksNotifierTitle' .. levelCapitalized,
    'FloatFooter:SnacksNotifierFooter' .. levelCapitalized,
  }

  -- Calculate position (centered horizontally, near top)
  local row = topPadding
  local col = math.floor((vim.o.columns - width) / 2)

  -- create win with snacks API
  Snacks.win {
    relative = 'editor',
    position = 'float',
    buf = bufnr,
    height = height,
    width = width,
    row = row,
    col = col,
    title = vim.trim(title) ~= '' and '  ' .. title .. '  ' or nil,
    title_pos = 'center',
    footer = footer and '  ' .. footer .. '  ' or nil,
    footer_pos = 'center',
    border = 'rounded',
    ft = notif.ft or 'markdown',
    wo = {
      winhighlight = table.concat(highlights, ','),
      wrap = notif.ft ~= 'lua',
      linebreak = true,
      breakindent = true,
      statuscolumn = '  ',
      cursorline = true,
      cursorlineopt = 'both',
      winfixbuf = true,
      fillchars = 'fold: ,eob: ',
      foldmethod = 'expr',
      foldexpr = 'v:lua.vim.treesitter.foldexpr()',
      conceallevel = 2,
      concealcursor = 'nc',
      number = false,
      relativenumber = false,
      signcolumn = 'no',
      winblend = 0,
    },
    bo = {
      modifiable = false,
      bufhidden = 'wipe',
    },
    keys = {
      ['<Tab>'] = function()
        if idx == #history then
          vim.notify('Already at last notification', vim.log.levels.INFO)
          return
        end
        vim.cmd.close()
        M.openNotif(idx + 1)
      end,
      ['<S-Tab>'] = function()
        if idx == 1 then
          vim.notify('Already at first notification', vim.log.levels.INFO)
          return
        end
        vim.cmd.close()
        M.openNotif(idx - 1)
      end,
      ['q'] = function()
        vim.cmd.close()
      end,
      ['<Esc>'] = function()
        vim.cmd.close()
      end,
      ['j'] = function()
        if idx == #history then
          return
        end
        vim.cmd.close()
        M.openNotif(idx + 1)
      end,
      ['k'] = function()
        if idx == 1 then
          return
        end
        vim.cmd.close()
        M.openNotif(idx - 1)
      end,
    },
  }
end

return M
