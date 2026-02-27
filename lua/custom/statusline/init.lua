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
    vim.cmd 'redrawstatus'
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

-- ---------------------------------------------------------------------------
-- Eval bridge
-- ---------------------------------------------------------------------------
function M.eval()
  local winid = vim.g.statusline_winid or vim.api.nvim_get_current_win()
  local ok, result = pcall(builder.render, winid)
  if ok then
    return result
  end
  return ' [statusline error: ' .. tostring(result) .. '] '
end

-- ---------------------------------------------------------------------------
-- Autocmds — each targets the MINIMUM set of dirty components
-- ---------------------------------------------------------------------------
local function setup_autocmds()
  local group = vim.api.nvim_create_augroup('CustomStatusline', { clear = true })

  -- ── Window / buffer transitions ──────────────────────────────────────────
  -- Active-window highlight changes: mark ALL dirty because the base hl
  -- (StatusLine vs StatusLineNC) affects every segment's appearance.
  vim.api.nvim_create_autocmd({
    'BufEnter',
    'BufLeave',
    'WinEnter',
    'WinLeave',
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
  vim.api.nvim_create_autocmd('ModeChanged', {
    group = group,
    callback = vim.schedule_wrap(schedule_redraw),
  })

  -- ── File writes: invalidate file + git ────────────────────────────────────
  vim.api.nvim_create_autocmd({ 'BufWritePost', 'BufReadPost' }, {
    group = group,
    callback = function(args)
      require('custom.statusline.components.file').invalidate(args.buf)
      builder.mark_dirty 'file'
      git_comp.update(vim.fn.getcwd())
      -- git callback calls schedule_redraw when async fetch completes
    end,
  })

  -- ── BufEnter: invalidate file cache for this buffer ───────────────────────
  vim.api.nvim_create_autocmd('BufEnter', {
    group = group,
    callback = function(args)
      require('custom.statusline.components.file').invalidate(args.buf)
      builder.mark_dirty 'file'
    end,
  })

  -- ── Option changes ────────────────────────────────────────────────────────
  vim.api.nvim_create_autocmd('OptionSet', {
    group = group,
    pattern = 'paste,spell,wrap',
    callback = function()
      builder.mark_dirty 'system'
      schedule_redraw()
    end,
  })

  vim.api.nvim_create_autocmd('OptionSet', {
    group = group,
    pattern = 'fileencoding,fileformat',
    callback = function(args)
      require('custom.statusline.components.file').invalidate(args.buf)
      builder.mark_dirty 'file'
      schedule_redraw()
    end,
  })

  -- ── Macro recording ───────────────────────────────────────────────────────
  vim.api.nvim_create_autocmd({ 'RecordingEnter', 'RecordingLeave' }, {
    group = group,
    callback = function()
      builder.mark_dirty 'system'
      schedule_redraw()
    end,
  })

  -- ── Window resize ─────────────────────────────────────────────────────────
  -- Width-tier may change for every component → mark all dirty.
  vim.api.nvim_create_autocmd('VimResized', {
    group = group,
    callback = function()
      require('custom.statusline.components.file').invalidate_all()
      builder.mark_dirty_all()
      schedule_redraw()
    end,
  })

  -- ── Directory change: git + system (CWD display) ──────────────────────────
  vim.api.nvim_create_autocmd('DirChanged', {
    group = group,
    callback = function()
      require('custom.statusline.components.system').invalidate_cwd()
      builder.mark_dirty 'git'
      builder.mark_dirty 'system'
      git_comp.update(vim.fn.getcwd())
      schedule_redraw()
    end,
  })

  -- ── Git ───────────────────────────────────────────────────────────────────
  -- git_comp.update fires an async fetch; its callback marks git dirty
  -- and calls schedule_redraw when the result is ready.
  vim.api.nvim_create_autocmd({ 'BufWritePost', 'BufEnter', 'DirChanged' }, {
    group = group,
    callback = function()
      git_comp.update(vim.fn.getcwd())
    end,
  })

  -- ── LSP progress ──────────────────────────────────────────────────────────
  local has_lsp_progress = pcall(vim.api.nvim_get_autocmds, { event = 'LspProgress' })
  if has_lsp_progress then
    vim.api.nvim_create_autocmd('LspProgress', {
      group = group,
      callback = function(ev)
        lsp_comp.on_progress(ev)
      end,
    })
  end

  -- ── LSP attach / detach ───────────────────────────────────────────────────
  vim.api.nvim_create_autocmd('LspAttach', {
    group = group,
    callback = function(args)
      lsp_comp.invalidate_clients(args.buf)
      builder.mark_dirty 'lsp'
      schedule_redraw()
    end,
  })

  vim.api.nvim_create_autocmd('LspDetach', {
    group = group,
    callback = function(args)
      lsp_comp.invalidate_clients(args.buf)
      local cid = args.data and args.data.client_id
      if cid then
        lsp_comp.clear_client(cid)
      end
      builder.mark_dirty 'lsp'
      schedule_redraw()
    end,
  })

  -- ── Diagnostics ───────────────────────────────────────────────────────────
  vim.api.nvim_create_autocmd('DiagnosticChanged', {
    group = group,
    callback = function(args)
      lsp_comp.invalidate_diags(args.buf)
      builder.mark_dirty 'lsp'
      schedule_redraw()
    end,
  })

  -- ── Colorscheme ───────────────────────────────────────────────────────────
  vim.api.nvim_create_autocmd('ColorScheme', {
    group = group,
    callback = function()
      vim.schedule(function()
        require('custom.statusline.highlights').setup()
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
  sections = {
    { side = 'left', comp = 'mode' },
    { side = 'left', comp = 'file' },
    { side = 'left', comp = 'git' },
    { side = 'right', comp = 'lsp' },
    { side = 'right', comp = 'system' },
    { side = 'right', comp = 'cursor' },
  },
}

local function make_render_fn(key)
  local mode_comp = require 'custom.statusline.components.mode'
  local file_comp = require 'custom.statusline.components.file'
  local cursor_comp = require 'custom.statusline.components.cursor'
  local sys_comp = require 'custom.statusline.components.system'

  local fns = {
    mode = function(w, _b, _a)
      local s, _ = mode_comp.render()
      return s
    end,
    file = function(w, b, a)
      return file_comp.render(w, b, a)
    end,
    git = function(w, _b, _a)
      return git_comp.render(w)
    end,
    lsp = function(w, b, _a)
      return lsp_comp.render(w, b)
    end,
    cursor = function(w, _b, _a)
      return cursor_comp.render(w)
    end,
    system = function(w, _b, _a)
      return sys_comp.render(w)
    end,
  }
  return fns[key] or function()
    return ''
  end
end

-- ---------------------------------------------------------------------------
-- Public entry point
-- ---------------------------------------------------------------------------
function M.setup(user_opts)
  local opts = vim.tbl_deep_extend('force', defaults, user_opts or {})

  builder = require 'custom.statusline.builder'
  git_comp = require 'custom.statusline.components.git'
  lsp_comp = require 'custom.statusline.components.lsp'

  require('custom.statusline.highlights').setup()

  lsp_comp.redraw_fn = function()
    builder.mark_dirty 'lsp'
    schedule_redraw()
  end

  git_comp.redraw_fn = function()
    builder.mark_dirty 'git'
    schedule_redraw()
  end

  -- Register each section with its id so mark_dirty() can target it.
  for _, sec in ipairs(opts.sections) do
    builder.add(sec.side, make_render_fn(sec.comp), sec.comp)
  end

  vim.o.showmode = false
  vim.o.laststatus = opts.global and 3 or 2
  vim.o.statusline = "%!v:lua.require('custom.statusline').eval()"

  setup_autocmds()
  git_comp.update(vim.fn.getcwd())
end

return M
