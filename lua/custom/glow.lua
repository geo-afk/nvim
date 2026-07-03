-- =============================================================================
-- glow.lua — Charmbracelet Glow integration for Neovim (Redesigned)
-- =============================================================================
-- Uses custom.float_term for robust terminal handling and custom.ui for inputs.
-- =============================================================================

local M = {}

-- ─── Dependencies ────────────────────────────────────────────────────────────

local term = require("custom.float_term.term")
local ui = require("custom.ui")

-- ─── Configuration ───────────────────────────────────────────────────────────

M.config = {
  -- Glow style: "auto" | "dark" | "light" | path to JSON stylesheet
  style = "auto",

  -- Word-wrap width (0 = disabled, inherits terminal width)
  width = 100,

  -- Preserve newlines in output (-n flag)
  preserve_newlines = false,

  -- Automatically refresh the preview on :w when auto_preview is active
  auto_refresh = true,

  -- Keymaps (set to false to disable a specific mapping)
  keymaps = {
    preview_file = "<leader>ip", -- preview current file
    preview_visual = "<leader>iv", -- preview visual selection
    preview_url = "<leader>iu", -- preview a URL (prompts for input)
    open_tui = "<leader>it", -- open Glow TUI in a float
    open_tui_cwd = "<leader>id", -- open TUI browsing the cwd
    toggle_auto = "<leader>ia", -- toggle auto-preview on save
  },
}

-- ─── Internal State ──────────────────────────────────────────────────────────

local state = {
  auto_preview_enabled = false,
  au_group = nil,
}

-- ─── Helpers ─────────────────────────────────────────────────────────────────

--- Check whether glow exists on PATH.
local function glow_available()
  return vim.fn.executable("glow") == 1
end

--- Pretty installation notice.
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

--- Build the glow CLI argument list.
local function build_cmd(extra)
  local cfg = M.config
  local cmd = { "glow" }

  if cfg.style and cfg.style ~= "" then
    table.insert(cmd, "-s")
    table.insert(cmd, cfg.style)
  end

  if cfg.width and cfg.width > 0 then
    table.insert(cmd, "-w")
    table.insert(cmd, tostring(cfg.width))
  end

  if cfg.preserve_newlines then
    table.insert(cmd, "-n")
  end

  if extra then
    if type(extra) == "table" then
      vim.list_extend(cmd, extra)
    else
      table.insert(cmd, extra)
    end
  end

  return cmd
end

--- Internal runner that uses float_term.
local function run_glow(args, opts)
  if not glow_available() then
    notify_missing()
    return
  end

  opts = opts or {}
  local cmd = build_cmd(args)
  return term.create_terminal(cmd, {
    title = opts.title or "󱗞 Glow Preview",
    on_exit = opts.on_exit,
  })
end

-- ─── Public API ──────────────────────────────────────────────────────────────

--- Preview the current buffer.
function M.preview_file()
  local filepath = vim.api.nvim_buf_get_name(0)
  local ft = vim.bo.filetype
  local is_temp = false

  -- If no file on disk or has unsaved changes, write to a temp file
  if filepath == "" or vim.bo.modified then
    local tmp = vim.fn.tempname() .. ".md"
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    vim.fn.writefile(lines, tmp)
    filepath = tmp
    is_temp = true
  end

  -- Warn if not markdown
  if ft ~= "markdown" and ft ~= "md" and ft ~= "" then
    vim.notify("Filetype '" .. ft .. "' is not markdown. Glow may not render correctly.", vim.log.levels.INFO)
  end

  run_glow(filepath, {
    on_exit = function()
      if is_temp then
        os.remove(filepath)
      end
    end,
  })
end

--- Preview visual selection.
function M.preview_visual()
  -- Get the visual selection lines
  local start_line = vim.fn.line("'<")
  local end_line = vim.fn.line("'>")
  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)

  local tmp = vim.fn.tempname() .. ".md"
  vim.fn.writefile(lines, tmp)

  run_glow(tmp, {
    title = "󱗞 Glow Selection",
    on_exit = function()
      os.remove(tmp)
    end,
  })
end

--- Prompt for a URL and preview it.
function M.preview_url()
  ui.input({
    prompt = " Glow URL: ",
    title = " 󱗞 Open Markdown URL ",
    placeholder = "https://github.com/...",
  }, function(url)
    if url and url ~= "" then
      run_glow(url, { title = "󱗞 Glow: " .. url })
    end
  end)
end

--- Open Glow TUI browser.
function M.open_tui(dir)
  local target
  if type(dir) == "table" and dir.args then
    target = dir.args ~= "" and dir.args or nil
  elseif type(dir) == "string" then
    target = dir
  end
  target = target or vim.fn.expand("%:p:h")
  run_glow({ "-t", target }, { title = "󱗞 Glow Browser" })
end

--- Open Glow TUI in current working directory.
function M.open_tui_cwd()
  M.open_tui(vim.fn.getcwd())
end

--- Toggle auto-preview on save.
function M.toggle_auto_preview()
  state.auto_preview_enabled = not state.auto_preview_enabled

  if state.auto_preview_enabled then
    state.au_group = vim.api.nvim_create_augroup("GlowAutoPreview", { clear = true })
    vim.api.nvim_create_autocmd("BufWritePost", {
      group = state.au_group,
      pattern = { "*.md", "*.markdown" },
      callback = function()
        M.preview_file()
      end,
    })
    vim.notify("Glow auto-preview ON", vim.log.levels.INFO)
  else
    if state.au_group then
      vim.api.nvim_del_augroup_by_id(state.au_group)
      state.au_group = nil
    end
    vim.notify("Glow auto-preview OFF", vim.log.levels.INFO)
  end
end

-- ─── Setup ───────────────────────────────────────────────────────────────────

function M.setup(user_config)
  if user_config then
    M.config = vim.tbl_deep_extend("force", M.config, user_config)
  end

  -- Commands
  vim.api.nvim_create_user_command("GlowPreview", M.preview_file, { desc = "Glow: Preview current file" })
  vim.api.nvim_create_user_command("GlowURL", M.preview_url, { desc = "Glow: Preview a URL" })
  vim.api.nvim_create_user_command("GlowTUI", M.open_tui, { desc = "Glow: Open TUI (current dir)" })
  vim.api.nvim_create_user_command("GlowTUICwd", M.open_tui_cwd, { desc = "Glow: Open TUI (cwd)" })
  vim.api.nvim_create_user_command("GlowAutoToggle", M.toggle_auto_preview, { desc = "Glow: Toggle auto-preview" })
  vim.api.nvim_create_user_command("GlowVisual", M.preview_visual, { range = true, desc = "Glow: Preview visual selection" })

  -- Keymaps
  local km = M.config.keymaps
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "markdown",
    group = vim.api.nvim_create_augroup("GlowFiletype", { clear = true }),
    callback = function(ev)
      local buf = ev.buf
      local ok, wk = pcall(require, "which-key")

      if ok then
        wk.add({
          { "<leader>i", group = "Preview / Media", icon = { icon = "󰋩 ", hl = "MiniIconsCyan" }, buffer = buf },
          { km.preview_file, M.preview_file, desc = "Glow: preview file", buffer = buf },
          { km.preview_visual, "<Esc><cmd>GlowVisual<CR>", desc = "Glow: preview selection", mode = "v", buffer = buf },
          { km.preview_url, M.preview_url, desc = "Glow: preview URL", buffer = buf },
          { km.open_tui, M.open_tui, desc = "Glow: open TUI", buffer = buf },
          { km.open_tui_cwd, M.open_tui_cwd, desc = "Glow: browse CWD in TUI", buffer = buf },
          { km.toggle_auto, M.toggle_auto_preview, desc = "Glow: toggle auto-preview", buffer = buf },
        })
      else
        local bopts = { buffer = buf, silent = true }
        if km.preview_file then vim.keymap.set("n", km.preview_file, M.preview_file, bopts) end
        if km.preview_visual then vim.keymap.set("v", km.preview_visual, "<Esc><cmd>GlowVisual<CR>", bopts) end
        if km.preview_url then vim.keymap.set("n", km.preview_url, M.preview_url, bopts) end
        if km.open_tui then vim.keymap.set("n", km.open_tui, M.open_tui, bopts) end
        if km.open_tui_cwd then vim.keymap.set("n", km.open_tui_cwd, M.open_tui_cwd, bopts) end
        if km.toggle_auto then vim.keymap.set("n", km.toggle_auto, M.toggle_auto_preview, bopts) end
      end
    end,
  })

  -- Check availability on startup
  if not glow_available() then
    vim.defer_fn(notify_missing, 1000)
  end
end

return M
