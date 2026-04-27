--------------------------------------------------------------------------------
-- terminal_manager/config.lua
-- Default configuration.  Users mutate M.config (on the root module) after
-- requiring it – or via the profile manager / wizard UI.
--------------------------------------------------------------------------------

local M = {}

M.defaults = {
  -- ── Panel dimensions ─────────────────────────────────────────────────────
  sidebar_width = 26,
  panel_height = 0.33, -- fraction of total screen lines
  min_panel_lines = 6, -- hard minimum (lines)
  max_panel_frac = 0.60, -- hard maximum (fraction)
  float = {
    width = 0.80,
    height = 0.80,
    border = "rounded",
    title_pos = "center",
    zindex = 60,
    winblend = 0,
  },

  -- ── Shell / env ───────────────────────────────────────────────────────────
  shell = nil, -- nil → vim.o.shell; applies to profiles with shell=nil
  inherit_env = true,

  -- ── Profiles ──────────────────────────────────────────────────────────────
  default_profile = "Default",
  automation_profile = nil,

  -- Per-profile fields:
  --   name            string      Display name (required)
  --   shell           string|nil  Executable; nil → vim.o.shell
  --   args            string[]    Extra arguments for the shell
  --   env             table       Extra env vars; set key=false to unset
  --   cwd             string|nil  Working dir; nil → current pwd
  --   icon            string      Single char in sidebar + winbar
  --   color           string      Accent: blue green red yellow cyan
  --                               magenta orange white
  --   override_name   bool        Pin profile name as terminal title
  --   login_shell     bool        Auto-prepend -l to args
  --   startup_command string|nil  Command sent to shell after launch
  --   close_on_exit   bool        Remove slot when shell exits
  --   keymap          string|nil  Global mapping, e.g. "<leader>zg"
  --   description     string      One-line human description
  profiles = {
    {
      name = "Default",
      shell = nil,
      args = {},
      env = {},
      cwd = nil,
      icon = "$",
      color = "blue",
      override_name = false,
      login_shell = false,
      startup_command = nil,
      close_on_exit = false,
      keymap = nil,
      description = "System default shell",
    },
  },

  -- ── Misc ──────────────────────────────────────────────────────────────────
  skip_patterns = { "fzf", "claude", "lazygit" },
}

M.values = vim.deepcopy(M.defaults)

return M
