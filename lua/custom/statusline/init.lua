-- =============================================================================
-- statusline/init.lua  — dirty-flag partial update wiring
-- =============================================================================
--
-- Every autocmd now targets a specific component by id rather than calling
-- mark_dirty_all(). This means a DiagnosticChanged event only re-renders the
-- "lsp" segment; scrolling only re-renders "cursor" and "mode"; a git change
-- only re-renders "git". All other segments return their cached strings.
--
-- WHAT "PARTIAL UPDATE" MEANS IN THIS SYSTEM
-- ═══════════════════════════════════════════
-- At the terminal level: impossible — Neovim always repaints the full row.
-- At the Lua level: each component has a dirty flag. builder.render() only
-- calls the component's render function if dirty==true. The rest return
-- their last cached string. See builder.lua for the full explanation and
-- cost table.
--
-- EVENT → DIRTY COMPONENT MAPPING
-- ════════════════════════════════
--  BufEnter / BufLeave / WinEnter / WinLeave  → ALL (active hl changes)
--  BufWritePost / BufReadPost                  → file, git
--  OptionSet(paste,spell,wrap)                 → system
--  OptionSet(fileencoding,fileformat)          → file
--  RecordingEnter / RecordingLeave             → system
--  VimResized                                  → ALL (width tiers change)
--  DirChanged                                  → git, system (CWD display)
--  LspAttach / LspDetach                       → lsp
--  DiagnosticChanged                           → lsp
--  ColorScheme                                 → ALL (highlights rebuilt)
--  ModeChanged                                 → mode  (always-fresh; kept
--                                                        for the redraw nudge)
-- =============================================================================

local M = {}
local uv = vim.uv or vim.loop

local builder, git_comp, lsp_comp
local opts_ref
local anim_timer

-- ---------------------------------------------------------------------------
-- Time-gated redraw (16 ms minimum between explicit redraws)
-- ---------------------------------------------------------------------------
local REDRAW_MIN_MS = 16
local _last_redraw = 0
local _pending = false

local function redraw_now()
  _last_redraw = uv.now()
  local ok = pcall(vim.api.nvim__redraw, { statusline = true, flush = false })
  if not ok then
    vim.cmd("redrawstatus")
  end
end

local function schedule_redraw()
  if _pending then
    return
  end
  local gap = uv.now() - _last_redraw
  _pending = true
  if gap >= REDRAW_MIN_MS then
    vim.schedule(function()
      _pending = false
      redraw_now()
    end)
  else
    vim.defer_fn(function()
      _pending = false
      redraw_now()
    end, REDRAW_MIN_MS - gap + 1)
  end
end

M.schedule_redraw = schedule_redraw

local function pulse_redraw()
  if not opts_ref or not opts_ref.animation or not opts_ref.animation.enabled then
    schedule_redraw()
    return
  end
  if anim_timer then
    anim_timer:stop()
    anim_timer:close()
    anim_timer = nil
  end
  local steps = opts_ref.animation.steps or 5
  local tick = 0
  anim_timer = uv.new_timer()
  anim_timer:start(0, opts_ref.animation.interval or 45, vim.schedule_wrap(function()
    tick = tick + 1
    schedule_redraw()
    if tick >= steps and anim_timer then
      anim_timer:stop()
      anim_timer:close()
      anim_timer = nil
    end
  end))
end

-- ---------------------------------------------------------------------------
-- Eval bridge
-- ---------------------------------------------------------------------------
function M.eval()
  local winid = vim.g.statusline_winid or vim.api.nvim_get_current_win()
  local ok, result = pcall(builder.render, winid)
  if ok then
    return result
  end
  return " [statusline error: " .. tostring(result) .. "] "
end

-- ---------------------------------------------------------------------------
-- Autocmds — each targets the MINIMUM set of dirty components
-- ---------------------------------------------------------------------------
local function setup_autocmds()
  local group = vim.api.nvim_create_augroup("CustomStatusline", { clear = true })

  -- ── Window / buffer transitions ──────────────────────────────────────────
  -- Active-window highlight changes: mark ALL dirty because the base hl
  -- (StatusLine vs StatusLineNC) affects every segment's appearance.
  vim.api.nvim_create_autocmd({
    "BufEnter",
    "BufLeave",
    "WinEnter",
    "WinLeave",
  }, {
    group = group,
    callback = function()
      builder.mark_dirty_all()
      schedule_redraw()
    end,
  })

  -- ── Mode changes ──────────────────────────────────────────────────────────
  -- Mode is always-fresh, so no dirty-flag needed. Just nudge a redraw so
  -- the mode pill colour updates even if no other data changed.
  vim.api.nvim_create_autocmd("ModeChanged", {
    group = group,
    callback = vim.schedule_wrap(pulse_redraw),
  })

  -- ── File writes: invalidate file + git ────────────────────────────────────
  vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost" }, {
    group = group,
    callback = function(args)
      require("custom.statusline.components.file").invalidate(args.buf)
      builder.mark_dirty("file")
      git_comp.update(vim.fn.getcwd())
      -- git callback calls schedule_redraw when async fetch completes
    end,
  })

  -- ── BufEnter: invalidate file cache for this buffer ───────────────────────
  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    callback = function(args)
      require("custom.statusline.highlights").setup(opts_ref, args.buf)
      require("custom.statusline.components.file").invalidate(args.buf)
      builder.mark_dirty("file")
      builder.mark_dirty_all()
      pulse_redraw()
    end,
  })

  -- ── Option changes ────────────────────────────────────────────────────────
  vim.api.nvim_create_autocmd("OptionSet", {
    group = group,
    pattern = "paste,spell,wrap",
    callback = function()
      builder.mark_dirty("system")
      schedule_redraw()
    end,
  })

  vim.api.nvim_create_autocmd("OptionSet", {
    group = group,
    pattern = "fileencoding,fileformat",
    callback = function(args)
      require("custom.statusline.components.file").invalidate(args.buf)
      builder.mark_dirty("file")
      schedule_redraw()
    end,
  })

  -- ── Macro recording ───────────────────────────────────────────────────────
  vim.api.nvim_create_autocmd({ "RecordingEnter", "RecordingLeave" }, {
    group = group,
    callback = function()
      builder.mark_dirty("system")
      schedule_redraw()
    end,
  })

  -- ── Window resize ─────────────────────────────────────────────────────────
  -- Width-tier may change for every component → mark all dirty.
  vim.api.nvim_create_autocmd("VimResized", {
    group = group,
    callback = function()
      require("custom.statusline.components.file").invalidate_all()
      builder.mark_dirty_all()
      schedule_redraw()
    end,
  })

  -- ── Directory change: git + system (CWD display) ──────────────────────────
  vim.api.nvim_create_autocmd("DirChanged", {
    group = group,
    callback = function()
      require("custom.statusline.components.system").invalidate_cwd()
      builder.mark_dirty("git")
      builder.mark_dirty("system")
      git_comp.update(vim.fn.getcwd())
      schedule_redraw()
    end,
  })

  -- ── Git ───────────────────────────────────────────────────────────────────
  -- git_comp.update fires an async fetch; its callback marks git dirty
  -- and calls schedule_redraw when the result is ready.
  vim.api.nvim_create_autocmd({ "BufWritePost", "BufEnter", "DirChanged" }, {
    group = group,
    callback = function()
      git_comp.update(vim.fn.getcwd())
    end,
  })

  -- ── LSP attach / detach ───────────────────────────────────────────────────
  vim.api.nvim_create_autocmd("LspAttach", {
    group = group,
    callback = function(args)
      lsp_comp.invalidate_clients(args.buf)
      builder.mark_dirty("lsp")
      schedule_redraw()
    end,
  })

  vim.api.nvim_create_autocmd("LspDetach", {
    group = group,
    callback = function(args)
      lsp_comp.invalidate_clients(args.buf)
      local cid = args.data and args.data.client_id
      if cid then
        lsp_comp.clear_client(cid)
      end
      builder.mark_dirty("lsp")
      schedule_redraw()
    end,
  })

  -- ── Diagnostics ───────────────────────────────────────────────────────────
  vim.api.nvim_create_autocmd("DiagnosticChanged", {
    group = group,
    callback = function(args)
      lsp_comp.invalidate_diags(args.buf)
      builder.mark_dirty("lsp")
      schedule_redraw()
    end,
  })

  -- ── Colorscheme ───────────────────────────────────────────────────────────
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = group,
    callback = function()
      vim.schedule(function()
        require("custom.statusline.highlights").setup(opts_ref, vim.api.nvim_get_current_buf())
        builder.mark_dirty_all()
        schedule_redraw()
      end)
    end,
  })
end

-- ---------------------------------------------------------------------------
-- Configuration
-- ---------------------------------------------------------------------------
local defaults = {
  global = true,
}

local function make_variant_fn(key)
  local mode_comp = require("custom.statusline.components.mode")
  local file_comp = require("custom.statusline.components.file")
  local cursor_comp = require("custom.statusline.components.cursor")
  local sys_comp = require("custom.statusline.components.system")
  local fns = {
    mode = mode_comp.variants,
    file = file_comp.variants,
    git = git_comp.variants,
    lsp = lsp_comp.variants,
    cursor = cursor_comp.variants,
    system = sys_comp.variants,
  }
  return fns[key] or function()
    return {}
  end
end

-- ---------------------------------------------------------------------------
-- Public entry point
-- ---------------------------------------------------------------------------
function M.setup(user_opts)
  local opts = require("custom.statusline.config").setup(vim.tbl_deep_extend("force", defaults, user_opts or {}))
  opts_ref = opts

  builder = require("custom.statusline.builder")
  git_comp = require("custom.statusline.components.git")
  lsp_comp = require("custom.statusline.components.lsp")

  builder.reset()
  require("custom.statusline.highlights").setup(opts, vim.api.nvim_get_current_buf())

  lsp_comp.redraw_fn = function()
    builder.mark_dirty("lsp")
    schedule_redraw()
  end

  git_comp.redraw_fn = function()
    builder.mark_dirty("git")
    schedule_redraw()
  end

  -- Register each section with its id so mark_dirty() can target it.
  for _, sec in ipairs(opts.sections) do
    builder.add(sec.side, make_variant_fn(sec.comp), sec.comp, sec)
  end

  vim.o.showmode = false
  vim.o.laststatus = opts.global and 3 or 2
  vim.o.statusline = "%!v:lua.require('custom.statusline').eval()"

  setup_autocmds()
  vim.api.nvim_create_user_command("StatuslineDebug", function()
    vim.print(builder.debug())
  end, { force = true })
  git_comp.update(vim.fn.getcwd())
end

function M.debug()
  return builder and builder.debug() or {}
end

return M
