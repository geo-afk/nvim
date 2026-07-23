-- =============================================================================
--  custom/tv/channels.lua  ·  Channel registry for the television fuzzy finder
-- =============================================================================
--
--  Each channel entry defines:
--    name        string       tv channel identifier (passed to `tv <name>`)
--    label       string       Human-readable display name
--    icon        string       Icon for the channel picker UI
--    desc        string       Short description shown in picker
--    action      function     Default action:  fun(entries: string[])
--    keybinding  string?      Optional global keybinding (set during setup)
--
--  This table is the single source of truth for all channel configuration.
--  Handlers reference actions.lua for reusability across channels.
-- =============================================================================

local a = require("custom.tv.actions")

---@class TvChannel
---@field name        string
---@field label       string
---@field icon        string
---@field desc        string
---@field action      fun(entries: string[])
---@field keybinding  string?

---@type TvChannel[]
local M = {
  {
    name = "alias",
    label = "Shell Aliases",
    icon = "󰘳",
    desc = "Browse and insert shell aliases",
    action = a.insert_at_cursor,
    keybinding = "<leader>ta",
  },
  {
    name = "dirs",
    label = "Directories",
    icon = "",
    desc = "Jump to a directory",
    action = function(entries)
      local path = vim.trim(entries[1] or "")
      if path ~= "" then
        vim.cmd("tcd " .. vim.fn.fnameescape(path))
        vim.notify("[tv] cwd → " .. path, vim.log.levels.INFO)
      end
    end,
    keybinding = "<leader>td",
  },
  {
    name = "docker-images",
    label = "Docker Images",
    icon = "󰡨",
    desc = "Browse Docker images",
    action = a.copy_to_clipboard,
    keybinding = "<leader>tD",
  },
  {
    name = "dotfiles",
    label = "Dotfiles",
    icon = "󰒓", -- settings/gear
    desc = "Open dotfile configs",
    action = a.open_as_files,
    keybinding = "<leader>t.",
  },
  {
    name = "env",
    label = "Environment Variables",
    icon = "󱉯", -- terminal with variable
    desc = "Insert an env variable at cursor",
    action = a.insert_at_cursor,
    keybinding = "<leader>te",
  },

  {
    name = "files",
    label = "Files",
    icon = "󰈙",
    desc = "Fuzzy find files",
    action = a.open_as_files,
    keybinding = "<leader>tf",
  },
  {
    name = "git-branch",
    label = "Git Branches",
    icon = "󰊢",
    desc = "Checkout a git branch",
    action = a.git_checkout,
    keybinding = "<leader>gtb",
  },
  {
    name = "git-diff",
    label = "Git Diff",
    icon = "󰨝",
    desc = "Browse unstaged git changes",
    action = a.open_at_line,
    keybinding = "<leader>gtd",
  },
  {
    name = "git-log",
    label = "Git Log",
    icon = "󰜊",
    desc = "Browse commit history",
    action = a.git_show_commit,
    keybinding = "<leader>gtl",
  },
  {
    name = "git-reflog",
    label = "Git Reflog",
    icon = "󰔜",
    desc = "Browse git reflog",
    action = a.git_copy_hash,
    keybinding = "<leader>gtr",
  },
  {
    name = "git-repos",
    label = "Git Repos",
    icon = "󰳐",
    desc = "Open a git repository",
    action = a.open_git_repo,
    keybinding = "<leader>gtR",
  },
  {
    name = "nu-history",
    label = "Nushell History",
    icon = "󰝢",
    desc = "Re-run a nushell command",
    action = a.run_from_history,
    keybinding = "<leader>tN",
  },
  {
    name = "pwsh-history",
    label = "PowerShell History",
    icon = "󰨊",
    desc = "Re-run a PowerShell command",
    action = a.run_from_history,
    keybinding = "<leader>tP",
  },
  {
    name = "text",
    label = "Text Search",
    icon = "󰞃",
    desc = "Ripgrep search in files",
    action = a.open_at_line,
    keybinding = "<leader>ts",
  },
  {
    name = "tldr",
    label = "TLDR Pages",
    icon = "󰘥",
    desc = "Browse TLDR command pages",
    action = a.copy_to_clipboard,
    keybinding = "<leader>tT",
  },
}

return M
