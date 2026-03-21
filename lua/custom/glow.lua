-- =============================================================================
-- glow.lua — Charmbracelet Glow integration for Neovim
-- =============================================================================
-- Features:
--   • Availability check with helpful install message
--   • Preview current markdown buffer in a floating window
--   • Preview visually-selected text as markdown
--   • Preview any markdown URL (GitHub, GitLab, raw HTTP)
--   • Open Glow's full TUI browser in a terminal split
--   • Open the TUI in the current directory
--   • Configurable style, width, and window dimensions
--   • Auto-refresh on save (optional)
--   • All keymaps scoped to markdown filetypes only (except URL preview)
-- =============================================================================
-- INSTALLATION (choose one):
--   lazy.nvim:  { dir = "~/.config/nvim/lua", name = "glow" }
--   OR simply:  require("glow").setup() in your init.lua after copying here
-- =============================================================================

local M = {}

-- ---------------------------------------------------------------------------
-- Default configuration
-- ---------------------------------------------------------------------------
M.config = {
  -- Glow style: "auto" | "dark" | "light" | path to JSON stylesheet
  style = "auto",

  -- Word-wrap width (0 = disabled, inherits terminal width)
  width = 100,

  -- Preserve newlines in output (-n flag)
  preserve_newlines = false,

  -- Floating preview window dimensions (as fraction of editor size)
  win_width = 0.85,
  win_height = 0.80,

  -- Border style for the floating window
  -- "rounded" | "single" | "double" | "shadow" | "none"
  border = "rounded",

  -- Automatically refresh the preview on :w when auto_preview is active
  auto_refresh = true,

  -- Keymaps (set to false to disable a specific mapping)
  keymaps = {
    preview_file = "<leader>mp", -- preview current file
    preview_visual = "<leader>mv", -- preview visual selection
    preview_url = "<leader>mu", -- preview a URL (prompts for input)
    open_tui = "<leader>mt", -- open Glow TUI in a split
    open_tui_cwd = "<leader>md", -- open TUI browsing the cwd
    toggle_auto = "<leader>ma", -- toggle auto-preview on save
  },
}

-- ---------------------------------------------------------------------------
-- Internal state
-- ---------------------------------------------------------------------------
local state = {
  win = nil, -- floating window handle
  buf = nil, -- floating buffer handle
  auto_win = false, -- auto-preview active?
  au_group = nil, -- autocommand group id
}

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

--- Check whether glow exists on PATH.
local function glow_available()
  return vim.fn.executable("glow") == 1
end

--- Pretty installation notice (shown once per session if glow is absent).
local _notified = false
local function notify_missing()
  if _notified then
    return
  end
  _notified = true
  local lines = {
    "  Glow is not installed or not on PATH.",
    "",
    "  Install it with one of:",
    "    Windows :  winget install charmbracelet.glow",
    "    macOS   :  brew install glow",
    "    Ubuntu  :  sudo apt install glow",
    "    Arch    :  pacman -S glow",
    "    Go      :  go install github.com/charmbracelet/glow@latest",
    "",
    "  After installing, restart Neovim.",
  }
  vim.notify(table.concat(lines, "\n"), vim.log.levels.WARN, {
    title = "glow.nvim",
  })
end

--- Build the glow CLI argument list from current config.
local function build_args(extra)
  local cfg = M.config
  local args = {}

  -- Style
  if cfg.style and cfg.style ~= "" then
    table.insert(args, "-s")
    table.insert(args, cfg.style)
  end

  -- Width
  if cfg.width and cfg.width >= 0 then
    table.insert(args, "-w")
    table.insert(args, tostring(cfg.width))
  end

  -- Preserve newlines
  if cfg.preserve_newlines then
    table.insert(args, "-n")
  end

  -- Append any caller-provided extras (e.g. a file path or URL)
  if extra then
    for _, v in ipairs(extra) do
      table.insert(args, v)
    end
  end

  return args
end

--- Close the floating preview window if it is open.
local function close_float()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    vim.api.nvim_buf_delete(state.buf, { force = true })
  end
  state.win = nil
  state.buf = nil
end

--- Open a centered floating terminal and run glow with `args`.
local function open_float_terminal(args)
  close_float()

  local ui_w = vim.o.columns
  local ui_h = vim.o.lines
  local cfg = M.config

  local win_w = math.floor(ui_w * cfg.win_width)
  local win_h = math.floor(ui_h * cfg.win_height)
  local row = math.floor((ui_h - win_h) / 2)
  local col = math.floor((ui_w - win_w) / 2)

  -- Create a scratch buffer for the terminal
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = win_w,
    height = win_h,
    row = row,
    col = col,
    style = "minimal",
    border = cfg.border,
    title = " 󱗞 Glow Preview ",
    title_pos = "center",
  })

  state.win = win
  state.buf = buf

  -- Build final command
  local cmd = vim.list_extend({ "glow" }, args)

  vim.fn.termopen(cmd, {
    on_exit = function()
      -- Allow 'q' to close the float after glow exits
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(buf) then
          vim.api.nvim_buf_set_keymap(buf, "n", "q", "", {
            noremap = true,
            silent = true,
            callback = close_float,
          })
          vim.api.nvim_buf_set_keymap(buf, "t", "q", "", {
            noremap = true,
            silent = true,
            callback = close_float,
          })
        end
      end)
    end,
  })

  -- Enter terminal insert mode so the output is immediately visible
  vim.cmd("startinsert")

  -- Press <Esc> or 'q' to close
  local opts = { noremap = true, silent = true, buffer = buf }
  vim.keymap.set("t", "<Esc>", close_float, opts)
  vim.keymap.set("n", "<Esc>", close_float, opts)
  vim.keymap.set("n", "q", close_float, opts)
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

--- Preview the current buffer (saves to a temp file if it has unsaved changes).
function M.preview_file()
  if not glow_available() then
    notify_missing()
    return
  end

  local filepath = vim.api.nvim_buf_get_name(0)
  local ft = vim.bo.filetype

  -- If no file on disk, write a temp file
  if filepath == "" or vim.bo.modified then
    local tmp = vim.fn.tempname() .. ".md"
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    vim.fn.writefile(lines, tmp)
    filepath = tmp
  end

  -- Warn if not markdown (but still preview)
  if ft ~= "markdown" and ft ~= "md" and ft ~= "" then
    vim.notify(
      "Current filetype is '" .. ft .. "', not markdown. Glow may not render as expected.",
      vim.log.levels.INFO,
      { title = "glow.nvim" }
    )
  end

  open_float_terminal(build_args({ filepath }))
end

--- Preview a visually selected range as markdown.
function M.preview_visual()
  if not glow_available() then
    notify_missing()
    return
  end

  -- Get the visual selection
  local start_line = vim.fn.line("'<")
  local end_line = vim.fn.line("'>")
  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)

  local tmp = vim.fn.tempname() .. ".md"
  vim.fn.writefile(lines, tmp)

  open_float_terminal(build_args({ tmp }))
end

--- Prompt for a URL and preview it with glow.
function M.preview_url()
  if not glow_available() then
    notify_missing()
    return
  end

  vim.ui.input({
    prompt = "  Glow URL (GitHub/GitLab repo or raw .md URL): ",
    default = "",
  }, function(url)
    if not url or url == "" then
      return
    end
    open_float_terminal(build_args({ url }))
  end)
end

--- Open Glow's interactive TUI in a horizontal split (optionally scoped to a dir).
function M.open_tui(dir)
  if not glow_available() then
    notify_missing()
    return
  end

  local target = dir or vim.fn.expand("%:p:h")

  -- Open a new horizontal split with a terminal
  vim.cmd("botright 20new")
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")

  local cmd = "glow -t " .. vim.fn.shellescape(target)
  vim.fn.termopen(cmd, {
    on_exit = function()
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(buf) then
          pcall(vim.api.nvim_buf_delete, buf, { force = true })
        end
      end)
    end,
  })
  vim.cmd("startinsert")
end

--- Open Glow TUI browsing the current working directory.
function M.open_tui_cwd()
  M.open_tui(vim.fn.getcwd())
end

--- Toggle auto-preview on save (for markdown buffers).
function M.toggle_auto_preview()
  if not glow_available() then
    notify_missing()
    return
  end

  state.auto_win = not state.auto_win

  if state.auto_win then
    state.au_group = vim.api.nvim_create_augroup("GlowAutoPreview", { clear = true })
    vim.api.nvim_create_autocmd("BufWritePost", {
      group = state.au_group,
      pattern = { "*.md", "*.markdown" },
      callback = function()
        M.preview_file()
      end,
    })
    vim.notify("Glow auto-preview ON", vim.log.levels.INFO, { title = "glow.nvim" })
  else
    if state.au_group then
      vim.api.nvim_del_augroup_by_id(state.au_group)
      state.au_group = nil
    end
    close_float()
    vim.notify("Glow auto-preview OFF", vim.log.levels.INFO, { title = "glow.nvim" })
  end
end

-- ---------------------------------------------------------------------------
-- Setup
-- ---------------------------------------------------------------------------

function M.setup(user_config)
  -- Merge user config into defaults
  if user_config then
    M.config = vim.tbl_deep_extend("force", M.config, user_config)
  end

  -- ── Commands ──────────────────────────────────────────────────────────────
  vim.api.nvim_create_user_command("GlowPreview", M.preview_file, { desc = "Glow: preview current file" })
  vim.api.nvim_create_user_command("GlowURL", M.preview_url, { desc = "Glow: preview a URL" })
  vim.api.nvim_create_user_command("GlowTUI", M.open_tui, { desc = "Glow: open TUI (current dir)" })
  vim.api.nvim_create_user_command("GlowTUICwd", M.open_tui_cwd, { desc = "Glow: open TUI (cwd)" })
  vim.api.nvim_create_user_command(
    "GlowAutoToggle",
    M.toggle_auto_preview,
    { desc = "Glow: toggle auto-preview on save" }
  )

  -- Visual-range preview command
  vim.api.nvim_create_user_command("GlowVisual", function()
    M.preview_visual()
  end, { range = true, desc = "Glow: preview visual selection" })

  -- ── Keymaps ───────────────────────────────────────────────────────────────
  local km = M.config.keymaps

  -- File preview & URL preview: global
  if km.preview_file then
    vim.keymap.set("n", km.preview_file, M.preview_file, {
      desc = "Glow: preview markdown file",
      silent = true,
    })
  end

  if km.preview_url then
    vim.keymap.set("n", km.preview_url, M.preview_url, {
      desc = "Glow: preview URL",
      silent = true,
    })
  end

  if km.open_tui_cwd then
    vim.keymap.set("n", km.open_tui_cwd, M.open_tui_cwd, {
      desc = "Glow: browse CWD in TUI",
      silent = true,
    })
  end

  if km.toggle_auto then
    vim.keymap.set("n", km.toggle_auto, M.toggle_auto_preview, {
      desc = "Glow: toggle auto-preview",
      silent = true,
    })
  end

  -- Markdown-only keymaps set via FileType autocmd
  vim.api.nvim_create_autocmd("FileType", {
    pattern = { "markdown" },
    group = vim.api.nvim_create_augroup("GlowFiletype", { clear = true }),
    callback = function(ev)
      local buf = ev.buf

      if km.preview_file then
        vim.keymap.set("n", km.preview_file, M.preview_file, {
          desc = "Glow: preview markdown file",
          silent = true,
          buffer = buf,
        })
      end

      if km.preview_visual then
        vim.keymap.set("v", km.preview_visual, "<Esc><cmd>GlowVisual<CR>", {
          desc = "Glow: preview visual selection",
          silent = true,
          buffer = buf,
        })
      end

      if km.open_tui then
        vim.keymap.set("n", km.open_tui, M.open_tui, {
          desc = "Glow: open TUI",
          silent = true,
          buffer = buf,
        })
      end
    end,
  })

  -- ── Startup availability check ────────────────────────────────────────────
  if not glow_available() then
    -- Defer so Neovim finishes loading before the notification appears
    vim.defer_fn(notify_missing, 500)
  end
end

-- ---------------------------------------------------------------------------
-- Lazy-setup guard: if someone calls require("glow") without .setup(), still
-- surface the availability check on first use.
-- ---------------------------------------------------------------------------
setmetatable(M, {
  __index = function(_, key)
    if key == "setup" then
      return M.setup
    end
    if not glow_available() then
      notify_missing()
      return function() end
    end
  end,
})

return M
