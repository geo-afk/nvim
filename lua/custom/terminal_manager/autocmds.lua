--------------------------------------------------------------------------------
-- custom/terminal_manager/autocmds.lua
-- All plugin autocommands.
--------------------------------------------------------------------------------

local state = require("custom.terminal_manager.state")
local utils = require("custom.terminal_manager.utils")

local M = {}

function M.setup()
  local aug = vim.api.nvim_create_augroup("TermManager", { clear = true })

  -- Apply keymaps + link detection to every interactive terminal we open.
  vim.api.nvim_create_autocmd("TermOpen", {
    group = aug,
    callback = function(ev)
      local cfg = require("custom.terminal_manager").config
      local bname = vim.api.nvim_buf_get_name(ev.buf)
      for _, pat in ipairs(cfg.skip_patterns) do
        if bname:find(pat, 1, true) then
          return
        end
      end

      local ko = function(desc)
        return { buffer = ev.buf, silent = true, desc = desc }
      end

      vim.keymap.set("t", "<Esc><Esc>", [[<C-\><C-n>]], ko("exit terminal mode"))
      vim.keymap.set("t", "<C-h>", [[<Cmd>wincmd h<CR>]], ko("go left"))
      vim.keymap.set("t", "<C-j>", [[<Cmd>wincmd j<CR>]], ko("go down"))
      vim.keymap.set("t", "<C-k>", [[<Cmd>wincmd k<CR>]], ko("go up"))
      vim.keymap.set("t", "<C-l>", [[<Cmd>wincmd l<CR>]], ko("go right"))

      -- Search keybinding in insert mode → escape first, then open search
      vim.keymap.set("t", "<C-f>", function()
        local keys = vim.api.nvim_replace_termcodes([[<C-\><C-n>]], true, false, true)
        vim.api.nvim_feedkeys(keys, "n", false)
        vim.schedule(function()
          local buf = ev.buf
          local win = vim.api.nvim_get_current_win()
          require("custom.terminal_manager.search").open(buf, win)
        end)
      end, ko("search in terminal"))

      vim.keymap.set("n", "<C-f>", function()
        local buf = ev.buf
        local win = vim.api.nvim_get_current_win()
        require("custom.terminal_manager.search").open(buf, win)
      end, ko("search in terminal"))

      vim.keymap.set("n", "<leader>zT", function()
        require("custom.terminal_manager").focus_sidebar()
      end, ko("focus sidebar"))

      -- Link navigation (gx/gf/gl) is wired by links.attach()
    end,
  })

  -- Sync ui.* handles when windows are closed externally.
  vim.api.nvim_create_autocmd("WinClosed", {
    group = aug,
    callback = function(ev)
      local closed = tonumber(ev.match)
      vim.schedule(function()
        if closed == state.ui.sidebar_win and not utils.win_ok(state.ui.sidebar_win) then
          state.ui.sidebar_win = nil
        end
        if closed == state.ui.term_win and not utils.win_ok(state.ui.term_win) then
          state.ui.term_win = nil
        end
        if closed == state.ui.term_win2 and not utils.win_ok(state.ui.term_win2) then
          state.ui.term_win2 = nil
          state.split_mode = false
          state.active_id2 = nil
        end
        if closed == state.ui.float_win and not utils.win_ok(state.ui.float_win) then
          utils.reset_float_handles()
        end
        if closed == state.help_win_h and not utils.win_ok(state.help_win_h) then
          state.help_win_h = nil
        end
        if not utils.panel_open() and not utils.float_open() then
          utils.reset_panel_handles()
        end
      end)
    end,
  })

  -- Track buffers deleted externally.
  vim.api.nvim_create_autocmd({ "BufUnload", "BufDelete" }, {
    group = aug,
    callback = function(ev)
      if ev.buf == state.ui.sidebar_buf then
        state.ui.sidebar_buf = nil
        if utils.win_ok(state.ui.sidebar_win) then
          pcall(vim.api.nvim_win_close, state.ui.sidebar_win, true)
          state.ui.sidebar_win = nil
        end
        return
      end
      for _, t in ipairs(state.terminals) do
        if t.buf == ev.buf then
          t.buf = nil
          t.venv = nil
          vim.schedule(function()
            require("custom.terminal_manager.sidebar").render()
            require("custom.terminal_manager.winbar").update_all()
          end)
          break
        end
      end
    end,
  })

  -- Refresh sidebar alive/dead indicators on focus change.
  vim.api.nvim_create_autocmd("WinEnter", {
    group = aug,
    callback = function()
      if utils.panel_open() then
        vim.schedule(function()
          require("custom.terminal_manager.sidebar").render()
        end)
      end
    end,
  })

  -- Invalidate venv cache when cwd changes (DirChanged).
  vim.api.nvim_create_autocmd("DirChanged", {
    group = aug,
    callback = function()
      require("custom.terminal_manager.venv").invalidate()
    end,
  })
end

return M
