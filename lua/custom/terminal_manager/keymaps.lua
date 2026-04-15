--------------------------------------------------------------------------------
-- custom.terminal_manager/keymaps.lua
-- Global keymaps and :Terminal* user commands.
-- All references to the main module are lazy (inside function bodies) so this
-- module can be required early during init without circular-dep issues.
--------------------------------------------------------------------------------

local M = {}

function M.setup()
  -- ── Normal-mode global keys ───────────────────────────────────────────────
  vim.keymap.set("n", "<leader>zt", function()
    require("custom.terminal_manager").toggle()
  end, { desc = "terminal: toggle panel" })

  vim.keymap.set("n", "<leader>zn", function()
    require("custom.terminal_manager").new_term()
  end, { desc = "terminal: new terminal" })

  vim.keymap.set("n", "<leader>zT", function()
    require("custom.terminal_manager").focus_sidebar()
  end, { desc = "terminal: focus sidebar" })

  vim.keymap.set("n", "<leader>zp", function()
    require("custom.terminal_manager").pick_profile(function(profile)
      require("custom.terminal_manager").new_term(nil, profile.name)
    end, "New terminal profile:")
  end, { desc = "terminal: new from profile" })

  -- ── Visual-mode: pipe selection into the active terminal ──────────────────
  vim.keymap.set("x", "<leader>zs", function()
    require("custom.terminal_manager").send_selection()
  end, { desc = "terminal: send selection" })

  -- ── <leader>z1 … <leader>z9: jump directly to the Nth managed terminal ───
  for i = 1, 9 do
    vim.keymap.set("n", "<leader>z" .. i, function()
      local st = require("custom.terminal_manager.state")
      if not st.terminals[i] then
        vim.notify(string.format("TermManager: no terminal #%d", i), vim.log.levels.INFO)
        return
      end
      local tm = require("custom.terminal_manager")
      if not require("custom.terminal_manager.utils").panel_open() then
        tm.open()
      end
      require("custom.terminal_manager.terminal").show(st.terminals[i])
    end, { desc = string.format("terminal: switch to #%d", i) })
  end

  -- ── User commands ─────────────────────────────────────────────────────────

  vim.api.nvim_create_user_command("TerminalNew", function(opts)
    local name = opts.args ~= "" and opts.args or nil
    require("custom.terminal_manager").new_term(name)
  end, { nargs = "?", desc = "Open a managed terminal" })

  vim.api.nvim_create_user_command("TerminalProfiles", function()
    require("custom.terminal_manager").show_profiles()
  end, { desc = "Show configured terminal profiles" })

  vim.api.nvim_create_user_command("TerminalAutomation", function(opts)
    local name = opts.args ~= "" and opts.args or nil
    require("custom.terminal_manager").new_automation_term(name)
  end, { nargs = "?", desc = "Open a managed terminal using the automation profile" })
end

return M
