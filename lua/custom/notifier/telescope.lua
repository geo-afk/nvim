-- custom/notifier/telescope.lua
-- Feature #4: Telescope history picker.
-- Loaded lazily — only when M.telescope() is called.
-- Gracefully no-ops if Telescope is not installed.

local M = {}

function M.pick()
  local ok_tel, tel = pcall(require, 'telescope')
  if not ok_tel then
    return
  end

  local pickers = require 'telescope.pickers'
  local finders = require 'telescope.finders'
  local config = require('telescope.config').values
  local actions = require 'telescope.actions'
  local action_state = require 'telescope.actions.state'
  local previewers = require 'telescope.previewers'

  local nm = require 'custom.notifier'
  local history = nm.get_history()

  local icons = { ERROR = ' ', WARN = ' ', INFO = ' ', DEBUG = ' ', TRACE = '󰓤 ' }
  local function lvl(n)
    local t = {
      [vim.log.levels.ERROR] = 'ERROR',
      [vim.log.levels.WARN] = 'WARN',
      [vim.log.levels.INFO] = 'INFO',
      [vim.log.levels.DEBUG] = 'DEBUG',
      [vim.log.levels.TRACE] = 'TRACE',
    }
    if type(n.level) == 'string' then
      return n.level:upper()
    end
    return t[n.level] or 'INFO'
  end

  -- Build display entries
  local entries = {}
  for i, n in ipairs(history) do
    local l = lvl(n)
    local ico = icons[l] or ' '
    local src = n.title and ('[' .. n.title .. '] ') or ''
    local first_line = n.message:match '^([^\n]+)' or n.message
    if #first_line > 60 then
      first_line = first_line:sub(1, 58) .. '…'
    end
    table.insert(entries, {
      idx = i,
      display = string.format('%s %s  %s%s%s', n.time_str, ico, src, first_line, n.message:find '\n' and '  ↵' or ''),
      ordinal = (n.title or '') .. ' ' .. n.message,
      notif = n,
      level = l,
    })
  end

  -- Highlight groups for each level (reuse notifier's hl groups)
  local hl_map = {
    ERROR = 'NotifyError',
    WARN = 'NotifyWarn',
    INFO = 'NotifyInfo',
    DEBUG = 'NotifyDebug',
    TRACE = 'NotifyTrace',
  }

  pickers
    .new({}, {
      prompt_title = '  Notification History',
      finder = finders.new_table {
        results = entries,
        entry_maker = function(e)
          return {
            value = e,
            display = e.display,
            ordinal = e.ordinal,
          }
        end,
      },
      sorter = config.generic_sorter {},

      -- Preview pane: shows the full message
      previewer = previewers.new_buffer_previewer {
        title = 'Full message',
        define_preview = function(self, entry)
          local n = entry.value.notif
          local l = entry.value.level
          local lines = {
            string.format('Level:  %s', l),
            string.format('Source: %s', n.title or '(none)'),
            string.format('Time:   %s %s', n.date_str or '', n.time_str or ''),
            string.rep('─', 40),
          }
          for _, ml in ipairs(vim.split(n.message, '\n', { plain = true })) do
            table.insert(lines, ml)
          end
          vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
          -- Highlight header
          local ns2 = vim.api.nvim_create_namespace 'notifier_tel_preview'
          vim.api.nvim_buf_add_highlight(self.state.bufnr, ns2, hl_map[l] or 'Normal', 0, 8, -1)
          vim.api.nvim_buf_add_highlight(self.state.bufnr, ns2, 'Comment', 3, 0, -1)
        end,
      },

      attach_mappings = function(prompt_bufnr, map)
        -- <CR>: yank full message to clipboard
        actions.select_default:replace(function()
          local sel = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if sel then
            vim.fn.setreg('+', sel.value.notif.message)
            vim.notify('[notifier] Message copied to clipboard.', vim.log.levels.INFO)
          end
        end)
        -- <C-d>: clear all history
        map('i', '<C-d>', function()
          actions.close(prompt_bufnr)
          nm.clear_history()
          vim.notify('[notifier] History cleared.', vim.log.levels.INFO)
        end)
        return true
      end,
    })
    :find()
end

return M
