--------------------------------------------------------------------------------
-- terminal_manager/config.lua
-- Default configuration table.
-- Users override M.config (on the main module) after requiring it.
--------------------------------------------------------------------------------

local M = {}

M.defaults = {
  -- ── Panel dimensions ─────────────────────────────────────────────────────
  sidebar_width = 26,
  panel_height = 0.33, -- fraction of total screen lines
  min_panel_lines = 6, -- hard minimum (lines)
  max_panel_frac = 0.60, -- hard maximum (fraction)

  -- ── Shell ─────────────────────────────────────────────────────────────────
  -- nil → vim.o.shell.  Applies to profiles whose own `shell` field is nil.
  shell = nil,
  inherit_env = true,

  -- ── Profiles ──────────────────────────────────────────────────────────────
  default_profile = "Default",
  automation_profile = nil,

  -- Terminal profiles – mirror of VS Code terminal.integrated.profiles.*
  --
  -- Fields per profile:
  --   name          string      Display name (required)
  --   shell         string|nil  Executable; nil → vim.o.shell
  --   args          string[]    Extra arguments for the shell
  --   env           table       Extra env vars; set a key to false to unset it
  --   cwd           string|nil  Working directory; nil → current pwd
  --   icon          string      Single char shown in sidebar + winbar
  --   color         string      Accent colour: blue green red yellow cyan
  --                                            magenta orange white
  --   override_name bool        Reserved – keep profile name as terminal title
  --
  -- When only one profile exists the picker is skipped on new_term().
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
    },
    -- Uncomment / add your own profiles:
    -- { name = "bash",    shell = "bash",    args = {},     icon = "$", color = "blue"    },
    -- { name = "zsh",     shell = "zsh",     args = {"-l"}, icon = "%", color = "green"   },
    -- { name = "fish",    shell = "fish",    args = {},     icon = ">", color = "cyan"    },
    -- { name = "Python",  shell = "python3", args = {"-i"}, icon = "~", color = "yellow"  },
    -- { name = "Node",    shell = "node",    args = {},     icon = ">", color = "green"   },
    -- { name = "nushell", shell = "nu",      args = {},     icon = ">", color = "magenta" },
  },

  -- ── Misc ──────────────────────────────────────────────────────────────────
  -- Buffers whose names contain any of these strings skip terminal keymaps.
  skip_patterns = { "fzf", "claude", "lazygit" },
}

return M
