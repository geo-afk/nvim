--------------------------------------------------------------------------------
-- terminal_manager/autocmds.lua
-- All plugin autocommands, set up once during init.
--------------------------------------------------------------------------------

local state = require("custom.terminal_manager.state")
local utils = require("custom.terminal_manager.utils")

local M = {}

function M.setup()
  local aug = vim.api.nvim_create_augroup("TermManager", { clear = true })

  -- ── Apply navigation keymaps to every interactive terminal we open ─────────
  -- Skips buffers matching config.skip_patterns (foreign plugin terminals).
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

      -- <Esc><Esc>: leave terminal mode without the raw <C-\><C-n> chord.
      vim.keymap.set("t", "<Esc><Esc>", [[<C-\><C-n>]], ko("exit terminal mode"))

      -- Window navigation from terminal insert mode.
      vim.keymap.set("t", "<C-h>", [[<Cmd>wincmd h<CR>]], ko("go to left window"))
      vim.keymap.set("t", "<C-j>", [[<Cmd>wincmd j<CR>]], ko("go to lower window"))
      vim.keymap.set("t", "<C-k>", [[<Cmd>wincmd k<CR>]], ko("go to upper window"))
      vim.keymap.set("t", "<C-l>", [[<Cmd>wincmd l<CR>]], ko("go to right window"))

      -- From normal mode inside a terminal: jump to the sidebar.
      vim.keymap.set("n", "<leader>zT", function()
        require("custom.terminal_manager").focus_sidebar()
      end, ko("focus sidebar"))
    end,
  })

  -- ── Keep ui.* handles consistent when windows are closed externally ────────
  -- (e.g. :q, :close, ZZ, another plugin closing the window)
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
        -- If help window was closed externally, clear its handle too.
        if closed == state.help_win_h and not utils.win_ok(state.help_win_h) then
          state.help_win_h = nil
        end
        if not utils.panel_open() then
          utils.reset_panel_handles()
        end
      end)
    end,
  })

  -- ── Track buffers deleted externally (:bd, another plugin, etc.) ──────────
  vim.api.nvim_create_autocmd({ "BufUnload", "BufDelete" }, {
    group = aug,
    callback = function(ev)
      -- Sidebar buffer deleted externally → close the sidebar window too.
      if ev.buf == state.ui.sidebar_buf then
        state.ui.sidebar_buf = nil
        if utils.win_ok(state.ui.sidebar_win) then
          pcall(vim.api.nvim_win_close, state.ui.sidebar_win, true)
          state.ui.sidebar_win = nil
        end
        return
      end

      -- Terminal buffer deleted externally → clear the slot so the next
      -- show() creates a fresh buffer and shell.
      for _, t in ipairs(state.terminals) do
        if t.buf == ev.buf then
          t.buf = nil
          vim.schedule(function()
            require("custom.terminal_manager.sidebar").render()
            require("custom.terminal_manager.winbar").update()
          end)
          break
        end
      end
    end,
  })

  -- ── Refresh alive/dead indicators whenever a window receives focus ─────────
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
end

return M
