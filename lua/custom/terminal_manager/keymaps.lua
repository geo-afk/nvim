--------------------------------------------------------------------------------
-- custom/terminal_manager/keymaps.lua
-- Global keymaps and :Terminal* user commands.
--------------------------------------------------------------------------------

local M = {}

function M.setup()
  -- ── Panel ─────────────────────────────────────────────────────────────────
  vim.keymap.set("n", "<leader>zt", function()
    require("custom.terminal_manager").toggle()
  end, { desc = "terminal: toggle panel" })
  vim.keymap.set("n", "<leader>zh", function()
    require("custom.terminal_manager").hide()
  end, { desc = "terminal: hide panel" })
  vim.keymap.set("n", "<leader>zT", function()
    require("custom.terminal_manager").focus_sidebar()
  end, { desc = "terminal: focus sidebar" })
  vim.keymap.set("n", "<leader>zn", function()
    require("custom.terminal_manager").new_term()
  end, { desc = "terminal: new terminal" })

  -- ── Profile ───────────────────────────────────────────────────────────────
  vim.keymap.set("n", "<leader>zp", function()
    require("custom.terminal_manager").pick_profile(function(p)
      require("custom.terminal_manager").new_term(nil, p.name)
    end, "New terminal profile:")
  end, { desc = "terminal: new from profile" })

  vim.keymap.set("n", "<leader>zP", function()
    require("custom.terminal_manager.profile_manager").open()
  end, { desc = "terminal: profile manager" })

  -- ── Split ─────────────────────────────────────────────────────────────────
  vim.keymap.set("n", "<leader>z|", function()
    require("custom.terminal_manager.split").toggle()
  end, { desc = "terminal: toggle split pane" })

  vim.keymap.set("n", "<leader>z<", function()
    require("custom.terminal_manager.split").focus(1)
  end, { desc = "terminal: focus primary pane" })

  vim.keymap.set("n", "<leader>z>", function()
    require("custom.terminal_manager.split").focus(2)
  end, { desc = "terminal: focus secondary pane" })

  vim.keymap.set("n", "<leader>zx", function()
    require("custom.terminal_manager.split").swap()
  end, { desc = "terminal: swap split terminals" })

  -- ── Send selection ────────────────────────────────────────────────────────
  vim.keymap.set("x", "<leader>zs", function()
    require("custom.terminal_manager").send_selection()
  end, { desc = "terminal: send selection" })

  -- ── Commands ──────────────────────────────────────────────────────────────
  vim.api.nvim_create_user_command("TerminalNew", function(opts)
    require("custom.terminal_manager").new_term(opts.args ~= "" and opts.args or nil)
  end, { nargs = "?", desc = "Open a managed terminal" })

  vim.api.nvim_create_user_command("TerminalProfiles", function()
    require("custom.terminal_manager.profile_manager").open()
  end, { desc = "Open profile manager" })

  vim.api.nvim_create_user_command("TerminalProfileNew", function()
    require("custom.terminal_manager.profile_wizard").open(nil, function(p)
      local cfg = require("custom.terminal_manager").config
      for _, ep in ipairs(cfg.profiles) do
        if ep.name == p.name then
          vim.notify("TermManager: profile '" .. p.name .. "' already exists", vim.log.levels.WARN)
          return
        end
      end
      table.insert(cfg.profiles, p)
      require("custom.terminal_manager.profiles").register_profile_keymaps()
      require("custom.terminal_manager.profile_store").save_all()
      vim.notify("TermManager: profile '" .. p.name .. "' created", vim.log.levels.INFO)
    end)
  end, { desc = "Create a new terminal profile" })

  vim.api.nvim_create_user_command("TerminalAutomation", function(opts)
    require("custom.terminal_manager").new_automation_term(opts.args ~= "" and opts.args or nil)
  end, { nargs = "?", desc = "Open terminal with automation profile" })

  vim.api.nvim_create_user_command("TerminalSplit", function()
    require("custom.terminal_manager.split").toggle()
  end, { desc = "Toggle split terminal pane" })

  vim.api.nvim_create_user_command("TerminalHide", function()
    require("custom.terminal_manager").hide()
  end, { desc = "Hide the terminal panel" })

  vim.api.nvim_create_user_command("TerminalSearch", function()
    local st = require("custom.terminal_manager.state")
    local t = require("custom.terminal_manager.utils").find_term(st.active_id)
    if t and t.buf then
      local win = st.ui.term_win
      require("custom.terminal_manager.search").open(t.buf, win)
    else
      vim.notify("TermManager: no active terminal", vim.log.levels.WARN)
    end
  end, { desc = "Search in active terminal" })

  -- Register per-profile keymaps
  require("custom.terminal_manager.profiles").register_profile_keymaps()
end

return M
