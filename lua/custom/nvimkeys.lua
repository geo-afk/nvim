-- ─────────────────────────────────────────────────────────────────────────────
-- nvimkeys.lua — paste this block into your init.lua (or require it)
--
-- What this does:
--   1. Registers :NvimKeys command and a keymap (<leader>km by default)
--   2. When triggered, opens nvimkeys in a floating terminal window
--   3. nvimkeys auto-detects $NVIM and connects back to THIS nvim instance
--   4. Inside the floating window you get live keymaps + extra actions:
--        y          yank selected keymap's LHS into your clipboard
--        Enter      yank LHS into clipboard then close the window
--        e          echo the keymap's description in the statusline
--        r          refresh keymaps live from this session
--        d          toggle the detail panel
--        /          search / filter
--        Tab        cycle mode tabs (Normal / Visual / Insert / …)
--        q / Esc    close the window
--
-- Configuration: edit the M.config table below.
-- ─────────────────────────────────────────────────────────────────────────────

local M = {}

M.config = {
  -- Path to the nvimkeys binary.
  -- If nvimkeys is on your PATH (e.g. ~/.local/bin/) just leave this as "nvimkeys".
  -- On Windows use the full path including .exe: "C:\\Users\\you\\bin\\nvimkeys.exe"
  exe = "C:\\Users\\KoolAid\\Pictures\\Projects\\go\\nvimkeys\\nvimkeys.exe",

  -- Keymap to open nvimkeys. Set to nil or "" to disable.
  key = "<leader>km",

  -- Floating window dimensions as fractions of the editor size.
  width = 0.92,
  height = 0.88,

  -- Border style: "rounded" | "single" | "double" | "solid" | "none"
  border = "rounded",

  -- Title shown in the border.
  title = " ⌨  nvimkeys ",

  -- Transparency (0 = opaque, 100 = invisible). 0 works for all colorschemes.
  winblend = 0,
}

-- ── Internal ──────────────────────────────────────────────────────────────────

-- Tracks the open window so we don't open duplicates.
local _win = nil
local _buf = nil

local function is_open()
  return _win ~= nil and vim.api.nvim_win_is_valid(_win)
end

local function close()
  if is_open() then
    pcall(vim.api.nvim_win_close, _win, true)
  end
  _win = nil
  _buf = nil
end

-- ── Main open function ────────────────────────────────────────────────────────

local function open()
  if is_open() then
    -- Already open: bring focus back to the window.
    vim.api.nvim_set_current_win(_win)
    return
  end

  local cfg = M.config
  local cols = vim.o.columns
  local lines = vim.o.lines

  local w = math.floor(cols * cfg.width)
  local h = math.floor(lines * cfg.height)
  local row = math.floor((lines - h) / 2)
  local col = math.floor((cols - w) / 2)

  -- Create a scratch buffer for the terminal.
  _buf = require("custom.ui.buffer").create_raw(false, true)

  -- Open a floating window.
  _win = require("custom.ui.window").open_raw(_buf, true, {
    relative = "editor",
    width = w,
    height = h,
    row = row,
    col = col,
    style = "minimal",
    border = cfg.border,
    title = cfg.title,
    title_pos = "center",
  })

  -- Transparency.
  if cfg.winblend > 0 then
    vim.api.nvim_set_option_value("winblend", cfg.winblend, { win = _win })
  end

  -- Launch nvimkeys inside the terminal.
  -- $NVIM is inherited automatically from the parent nvim process.
  vim.fn.termopen(cfg.exe, {
    on_exit = function(_, exit_code, _)
      -- Exit code 1 means a keymap was selected (LHS yanked to clipboard).
      if exit_code == 1 then
        vim.schedule(function()
          vim.notify("nvimkeys: keymap LHS copied to clipboard", vim.log.levels.INFO, { title = "nvimkeys" })
        end)
      end
      vim.schedule(close)
    end,
  })

  -- Enter terminal insert mode immediately so keypresses go to nvimkeys.
  vim.cmd("startinsert")

  -- Pressing Esc in the terminal (without entering normal mode) closes the window.
  -- We map it on the buffer so it doesn't interfere with other windows.
  vim.keymap.set("t", "<Esc>", function()
    close()
  end, { buffer = _buf, desc = "Close nvimkeys" })

  -- Also close when the window loses focus (optional quality-of-life tweak).
  -- Comment this out if you prefer the window to stay open in the background.
  vim.api.nvim_create_autocmd("WinLeave", {
    buffer = _buf,
    once = true,
    callback = function()
      -- Small delay so fast key presses that move focus don't kill the window.
      vim.defer_fn(function()
        if not is_open() then
          return
        end
        -- Only auto-close if focus left to a non-floating window.
        local cur = vim.api.nvim_get_current_win()
        local config = vim.api.nvim_win_get_config(cur)
        if config.relative == "" then
          close()
        end
      end, 100)
    end,
  })
end

-- ── Setup ─────────────────────────────────────────────────────────────────────

function M.setup(user_config)
  -- Merge user config over defaults.
  if user_config then
    for k, v in pairs(user_config) do
      M.config[k] = v
    end
  end

  -- Register :NvimKeys command.
  vim.api.nvim_create_user_command("NvimKeys", function()
    open()
  end, { desc = "Open the nvimkeys keymap browser" })

  -- Register keymap if configured.
  local key = M.config.key
  if key and key ~= "" then
    vim.keymap.set("n", key, open, {
      desc = "Open nvimkeys keymap browser",
      silent = true,
    })
  end
end

return M

-- ─────────────────────────────────────────────────────────────────────────────
-- QUICK-START (paste into init.lua):
--
--   -- Option A: require the file (if saved as a plugin or in lua/ dir)
--   require("nvimkeys").setup({
--     exe = "nvimkeys",  -- or full path: "C:\\Users\\you\\bin\\nvimkeys.exe"
--     key = "<leader>km",
--   })
--
--   -- Option B: inline (paste the whole file above, then add at the bottom):
--   M.setup({ exe = "nvimkeys", key = "<leader>km" })
--
-- After setup:
--   Press <leader>km  →  opens the floating keymap browser
--   :NvimKeys         →  same thing via command
-- ─────────────────────────────────────────────────────────────────────────────
