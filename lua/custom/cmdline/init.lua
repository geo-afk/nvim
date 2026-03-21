-- nvim-cmdline/init.lua
-- Public entry point.
--
-- PATH-INDEPENDENT: all sibling requires use (...) so this module loads
-- correctly regardless of what directory the user placed it in.
-- e.g.  require("custom.cmdline")          → (...)="custom.cmdline"
--       require("plugins.nvim-cmdline")     → (...)="plugins.nvim-cmdline"
--       require("nvim-cmdline")             → (...)="nvim-cmdline"
--
-- Usage:
--   require("your.path.here").setup({ ... })

---@type string  full module path, e.g. "custom.cmdline"
local _pkg = (...)

local colors = require(_pkg .. ".colors")
local ui = require(_pkg .. ".ui")

local M = {}

-- ---------------------------------------------------------------------------
-- Defaults (merged with user opts in setup)
-- ---------------------------------------------------------------------------

local DEFAULTS = {
  -- Replace native : / ? bindings
  replace_cmdline = true,
  replace_search = true,
  -- Pre-fill range when : is pressed from visual mode
  visual_range = true,

  ui = {
    width_ratio = 0.55,
    max_width = 86,
    min_width = 40,
    border_cmd = { "┌", "─", "┐", "│", "┘", "─", "└", "│" },
    border_search = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" },
  },

  animation = {
    enabled = true,
    steps = 4,
    duration_ms = 80,
  },

  completion = {
    debounce_ms = 40,
    auto_open = true,
    min_length = 1,
  },

  syntax = {
    enable = true,
  },

  range_preview = {
    enable = true,
    context = 2,
    max_lines = 8,
  },

  -- Live preview of :s/pat/rep/, :g/pat/, :d etc. directly in the buffer
  live_preview = {
    enable = true,
  },

  -- Set to true if your terminal uses a Nerd Font (enables icon glyphs).
  -- nil = auto-detect via vim.g.have_nerd_font; false = ASCII fallbacks always.
  nerd_font = nil,

  -- Any key can be set to false to disable, or to a string/table to remap.
  keymaps = {},
}

-- ---------------------------------------------------------------------------
-- setup()
-- ---------------------------------------------------------------------------

---Configure and activate nvim-cmdline.
---@param opts table?  Partial config merged over defaults.
function M.setup(opts)
  opts = opts or {}

  if type(opts) ~= "table" then
    vim.notify("[nvim-cmdline] setup() expects a table, got " .. type(opts), vim.log.levels.ERROR)
    return
  end

  local cfg = vim.tbl_deep_extend("force", DEFAULTS, opts)

  -- Merge all config sub-tables into ui.config
  ui.config = vim.tbl_deep_extend("force", ui.config, {
    width_ratio = cfg.ui.width_ratio,
    max_width = cfg.ui.max_width,
    min_width = cfg.ui.min_width,
    animation = cfg.animation,
    border_cmd = cfg.ui.border_cmd,
    border_search = cfg.ui.border_search,
    nerd_font = cfg.nerd_font,
    completion = cfg.completion,
    syntax = cfg.syntax,
    range_preview = cfg.range_preview,
    live_preview = cfg.live_preview,
    keymaps = vim.tbl_deep_extend("force", ui.config.keymaps, cfg.keymaps),
  })

  -- Highlight setup + automatic refresh on colorscheme change
  colors.setup_highlights()
  -- Preview groups read diff/diagnostic groups, refresh them too
  pcall(colors.setup_preview_highlights)
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("NvimCmdlineColors", { clear = true }),
    callback = function()
      colors.setup_highlights()
      pcall(colors.setup_preview_highlights)
    end,
  })

  -- ── Keymaps ────────────────────────────────────────────────────────────
  if cfg.replace_cmdline then
    vim.keymap.set("n", ":", function()
      ui.open("cmd")
    end, { noremap = true, silent = true, desc = "NvimCmdline: command mode" })

    if cfg.visual_range then
      vim.keymap.set("x", ":", function()
        -- Capture the window NOW, while still in visual mode, before <Esc>
        -- changes the active window or mode state.
        local vwin = vim.api.nvim_get_current_win()
        local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
        vim.api.nvim_feedkeys(esc, "nx", false)
        ui.open("cmd", { default = "'<,'>", prev_win = vwin })
      end, { noremap = true, silent = true, desc = "NvimCmdline: visual range" })
    end
  end

  if cfg.replace_search then
    vim.keymap.set("n", "/", function()
      ui.open("search_fwd")
    end, { noremap = true, silent = true, desc = "NvimCmdline: search /" })
    vim.keymap.set("n", "?", function()
      ui.open("search_bwd")
    end, { noremap = true, silent = true, desc = "NvimCmdline: search ?" })
  end

  -- ── User commands ─────────────────────────────────────────────────────
  vim.api.nvim_create_user_command("NvimCmdline", function(a)
    ui.open(a.args ~= "" and a.args or "cmd")
  end, {
    nargs = "?",
    complete = function()
      return { "cmd", "search_fwd", "search_bwd" }
    end,
    desc = "Open NvimCmdline",
  })

  vim.api.nvim_create_user_command("NvimCmdlineClose", ui.close, { desc = "Close NvimCmdline" })

  vim.g.nvim_cmdline_setup_done = 1
end

-- ---------------------------------------------------------------------------
-- Public API (thin pass-throughs)
-- ---------------------------------------------------------------------------

---Open the cmdline in the given mode.
---@param mode  string  "cmd"|"search_fwd"|"search_bwd"
---@param opts  table?  { default = "pre-filled text" }
M.open = function(mode, opts)
  return ui.open(mode, opts)
end

---Close if open.
M.close = function()
  return ui.close()
end

return M
