-- tabline/config.lua
-- Holds default configuration and the apply() merge helper.
-- Nothing here has side-effects; it is a pure data module.

local M = {}

---@class TablinePersistConfig
---@field enabled           boolean   Master switch; set false to disable the feature entirely
---@field data_dir          string    Where session JSON files are stored
---@field restore_on_startup boolean  Auto-restore when opening Neovim with no file arguments
---@field save_on_exit      boolean   Auto-save when Neovim exits
---@field skip_filetypes    string[]  Filetypes to exclude from the saved buffer list
---@field skip_dirs         string[]  Absolute directory paths where sessions should never be saved

---@class TablineConfig
---@field max_buffers      integer          Maximum number of buffer tabs shown at once (0 = unlimited)
---@field max_name_length  integer          Truncate filenames longer than this (0 = unlimited)
---@field padding          integer          Spaces on each side of a tab label
---@field modified_icon    string           Indicator appended when a buffer is modified
---@field close_icon       string           Close button character
---@field separator        string           Character between tabs (empty string = none)
---@field show_modified    boolean          Whether to show the modified indicator
---@field show_close       boolean          Whether to show the close button
---@field focus_on_close   string           Which buffer to focus after closing: "left"|"right"|"previous"
---@field keymaps          table            Keymap strings; set a key to false to disable
---@field persist          TablinePersistConfig  Buffer persistence / restore settings

M.defaults = {
  max_buffers     = 20,
  max_name_length = 24,
  padding         = 1,
  modified_icon   = "+",
  close_icon      = "×",
  separator       = "",        -- between tabs; "" = none, "│" = thin bar, etc.
  show_modified   = true,
  show_close      = true,
  focus_on_close  = "left",    -- "left" | "right" | "previous"

  keymaps = {
    next        = "<Tab>",
    prev        = "<S-Tab>",
    close       = "<A-c>",
    move_left   = "<leader>b<",
    move_right  = "<leader>b>",
  },

  -- ── Buffer persistence ──────────────────────────────────────────────────
  persist = {
    -- Master switch.  Set to false to disable the entire feature.
    enabled          = true,

    -- Where per-directory session JSON files are written.
    -- Each file is named after the sanitised working directory path.
    data_dir         = vim.fn.stdpath("data") .. "/tabline/sessions",

    -- Restore the previous buffer list when Neovim is opened with no file
    -- arguments in a directory that has a saved session.
    restore_on_startup = true,

    -- Automatically save the buffer list on exit.
    -- Covers both :qa / :wqa (VimLeavePre) and terminal-close (UILeave).
    save_on_exit     = true,

    -- Filetypes to exclude from the saved list.
    -- Buffers whose 'filetype' is in this list are silently skipped.
    skip_filetypes   = { "gitcommit", "gitrebase", "hgcommit", "svn", "fugitive" },

    -- Directories where sessions should never be saved or restored.
    -- Paths are resolved to absolute form before comparison.
    -- The home directory and filesystem root are skipped by default to
    -- avoid accidentally restoring hundreds of unrelated buffers.
    skip_dirs        = {
      vim.fn.expand("~"),
      "/",
    },
  },
}

--- Deep-merge user config over defaults.
--- Users only need to supply keys they want to override.
---@param user_config table|nil
---@return TablineConfig
function M.apply(user_config)
  return vim.tbl_deep_extend("force", M.defaults, user_config or {})
end

return M
