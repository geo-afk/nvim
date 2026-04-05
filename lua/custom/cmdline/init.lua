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
local nvim_utils = require("utils.nvim")

local M = {}

-- ---------------------------------------------------------------------------
-- Defaults
-- ---------------------------------------------------------------------------

local DEFAULTS = {
  replace_cmdline = true,
  replace_search = true,
  visual_range = true,

  ui = {
    width_ratio = 0.58,
    max_width = 92,
    min_width = 46,
    -- Both keys written to ui.config; must match field names in ui.lua M.config.
    -- (Previously only 'border_cmd' was set but MODE_INFO looked for 'border' —
    -- silent mismatch.  Fixed: MODE_INFO now uses 'border_cmd' / 'border_search'.)
    border_cmd = "rounded",
    border_search = "rounded",
    show_hint = true,
    transparency = true,
  },

  animation = { enabled = true, steps = 4, duration_ms = 75 },
  completion = { debounce_ms = 35, auto_open = true, min_length = 1 },
  syntax = { enable = true },

  range_preview = { enable = true, context = 2, max_lines = 8 },
  live_preview = { enable = true },

  nerd_font = nil,
  keymaps = {},
}

-- ---------------------------------------------------------------------------
-- setup()
-- ---------------------------------------------------------------------------

---Configure and activate nvim-cmdline.
---@param opts table?  Partial config merged over defaults.
function M.setup(opts)
  opts = opts or {}
  local cfg = vim.tbl_deep_extend("force", DEFAULTS, opts)

  -- Merge into ui.config.
  -- Key names here MUST match field names in ui.lua M.config.
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

  colors.setup_highlights()
  pcall(colors.setup_preview_highlights)

  nvim_utils.autocmd("ColorScheme", {
    group = "NvimCmdlineColors",
    callback = function()
      colors.setup_highlights()
      pcall(colors.setup_preview_highlights)
    end,
  })

  if cfg.replace_cmdline then
    nvim_utils.map("n", ":", function()
      ui.open("cmd")
    end, { noremap = true, silent = true })

    if cfg.visual_range then
      nvim_utils.map("x", ":", function()
        local vwin = vim.api.nvim_get_current_win()
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
        ui.open("cmd", { default = "'<,'>", prev_win = vwin })
      end, { noremap = true, silent = true })
    end
  end

  if cfg.replace_search then
    nvim_utils.map("n", "/", function()
      ui.open("search_fwd")
    end, { noremap = true, silent = true })

    nvim_utils.map("n", "?", function()
      ui.open("search_bwd")
    end, { noremap = true, silent = true })
  end

  nvim_utils.command("NvimCmdline", function(a)
    ui.open(a.args ~= "" and a.args or "cmd")
  end, {
    nargs = "?",
    complete = function()
      return { "cmd", "search_fwd", "search_bwd" }
    end,
  })

  nvim_utils.command("NvimCmdlineClose", ui.close, {})

  vim.g.nvim_cmdline_setup_done = 1
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

M.open = ui.open
M.close = ui.close

return M
