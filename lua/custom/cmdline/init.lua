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
  },

  animation = { enabled = true, steps = 4, duration_ms = 75 },
  completion = { debounce_ms = 35, auto_open = true, min_length = 1 },
  syntax = { enable = true },
  output = { min_width = 30, max_height_ratio = 0.60, default_wrap = false, enable_syntax = true },

  range_preview = { enable = true, context = 2, max_lines = 8 },
  live_preview = { enable = true },

  nerd_font = nil,
  keymaps = {},
}

local function validate_opts(opts)
  vim.validate({
    opts = { opts, "table", true },
  })

  if not opts then
    return
  end

  if opts.ui then
    vim.validate({
      ui = { opts.ui, "table" },
      width_ratio = { opts.ui.width_ratio, "number", true },
      max_width = { opts.ui.max_width, "number", true },
      min_width = { opts.ui.min_width, "number", true },
      border_cmd = { opts.ui.border_cmd, { "string", "table" }, true },
      border_search = { opts.ui.border_search, { "string", "table" }, true },
      show_hint = { opts.ui.show_hint, "boolean", true },
    })
  end

  if opts.animation then
    vim.validate({
      animation = { opts.animation, "table" },
      enabled = { opts.animation.enabled, "boolean", true },
      steps = { opts.animation.steps, "number", true },
      duration_ms = { opts.animation.duration_ms, "number", true },
    })
  end

  if opts.completion then
    vim.validate({
      completion = { opts.completion, "table" },
      debounce_ms = { opts.completion.debounce_ms, "number", true },
      auto_open = { opts.completion.auto_open, "boolean", true },
      min_length = { opts.completion.min_length, "number", true },
    })
  end

  if opts.syntax then
    vim.validate({
      syntax = { opts.syntax, "table" },
      enable = { opts.syntax.enable, "boolean", true },
    })
  end

  if opts.output then
    vim.validate({
      output = { opts.output, "table" },
      min_width = { opts.output.min_width, "number", true },
      max_height_ratio = { opts.output.max_height_ratio, "number", true },
      default_wrap = { opts.output.default_wrap, "boolean", true },
      enable_syntax = { opts.output.enable_syntax, "boolean", true },
    })
  end

  if opts.range_preview then
    vim.validate({
      range_preview = { opts.range_preview, "table" },
      enable = { opts.range_preview.enable, "boolean", true },
      context = { opts.range_preview.context, "number", true },
      max_lines = { opts.range_preview.max_lines, "number", true },
    })
  end

  if opts.live_preview then
    vim.validate({
      live_preview = { opts.live_preview, "table" },
      enable = { opts.live_preview.enable, "boolean", true },
    })
  end

  if opts.keymaps then
    vim.validate({
      keymaps = { opts.keymaps, "table" },
    })
  end
end

-- ---------------------------------------------------------------------------
-- setup()
-- ---------------------------------------------------------------------------

---Configure and activate nvim-cmdline.
---@param opts table?  Partial config merged over defaults.
function M.setup(opts)
  validate_opts(opts)
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
    show_hint = cfg.ui.show_hint,
    nerd_font = cfg.nerd_font,
    completion = cfg.completion,
    syntax = cfg.syntax,
    output = cfg.output,
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
  nvim_utils.command("NvimCmdlineLastOutput", function()
    require(_pkg .. ".output").show_last()
  end, {})

  vim.g.nvim_cmdline_setup_done = 1
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

M.open = ui.open
M.close = ui.close

return M
