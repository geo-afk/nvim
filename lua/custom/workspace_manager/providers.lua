--------------------------------------------------------------------------------
-- custom/workspace_manager/providers.lua
-- Adapters that know how to identify, hide and restore one kind of auxiliary
-- UI. Checked in registration order; first match wins. Each provider owns the
-- hide/restore mechanics for its kind so the core stash/restore logic in
-- actions.lua never has to special-case a specific plugin.
--
-- Why an adapter table instead of one generic window-hider:
--   terminal_manager and DAP-UI already own multi-window layouts with their
--   own lifecycle (hide != destroy is already true for them); reimplementing
--   that from raw window/buffer handles would duplicate and risk fighting
--   their internal state. The generic provider (last, catch-all) is the only
--   one that manipulates raw win/buf handles directly.
--
--- @class WorkspaceProvider
--- @field name string
--- @field singleton? boolean       true: at most one stashed instance ever exists
--- @field detect fun(win: integer, buf: integer): boolean
--- @field capture fun(win: integer, buf: integer): table       provider-specific metadata
--- @field label fun(meta: table): string
--- @field hide fun(win: integer, meta: table): boolean
--- @field restore fun(meta: table): integer|boolean|nil        new winid, `true` (already
---                                                              focused itself), or falsy on failure
--- @field terminate? fun(meta: table): boolean                  explicit process/session kill
--------------------------------------------------------------------------------
local M = {}

local providers = {}

--- Register a provider. Order matters: earlier providers are tried first.
function M.register(provider)
  table.insert(providers, provider)
end

--- Returns the first matching provider for (win, buf), or nil.
function M.match(win, buf)
  for _, p in ipairs(providers) do
    if p.detect(win, buf) then
      return p
    end
  end
end

function M.get(name)
  for _, p in ipairs(providers) do
    if p.name == name then
      return p
    end
  end
end

-- ── float_term (LazyGit + any other floating terminal tool) ──────────────────
-- custom.float_term.floating already tracks {buf, win, opts} per float id.
-- We only add hide/restore there (see that file); this adapter just wires it
-- into the registry and derives a label from the float's title.
M.register({
  name = "float_term",
  detect = function(win, _buf)
    local ok, floating = pcall(require, "custom.float_term.floating")
    return ok and floating.find_by_win(win) ~= nil
  end,
  capture = function(win, _buf)
    local floating = require("custom.float_term.floating")
    local id = floating.find_by_win(win)
    local f = floating.get(id)
    return { float_id = id, title = f and f.opts and f.opts.title }
  end,
  label = function(meta)
    return meta.title or "Floating terminal"
  end,
  hide = function(_win, meta)
    return require("custom.float_term.floating").hide(meta.float_id)
  end,
  restore = function(meta)
    return require("custom.float_term.floating").restore(meta.float_id)
  end,
  terminate = function(meta)
    require("custom.float_term.floating").close(meta.float_id)
    return true
  end,
})

-- ── managed_terminal (custom.terminal_manager panel) ──────────────────────────
-- The panel is one hide/show unit (sidebar + primary/secondary term windows +
-- its own float mode); terminal_manager already preserves jobs on hide().
-- singleton: stashing any of its windows stashes "the panel", once.
M.register({
  name = "managed_terminal",
  singleton = true,
  detect = function(win, _buf)
    -- Checked via package.loaded, not require(): terminal_manager is itself
    -- lazy-loaded, and if it has never been triggered, this window cannot
    -- possibly be one of its panel windows. require()-ing it here just to
    -- check would force-load it (keymaps, autocmds, the lot) as a side
    -- effect of stashing something completely unrelated.
    if not package.loaded["custom.terminal_manager"] then
      return false
    end
    local state = require("custom.terminal_manager.state")
    return win == state.ui.term_win
      or win == state.ui.term_win2
      or win == state.ui.sidebar_win
      or win == state.ui.float_win
  end,
  capture = function()
    return {}
  end,
  label = function()
    return "Terminal manager panel"
  end,
  hide = function()
    require("custom.terminal_manager").hide()
    return true
  end,
  restore = function()
    require("custom.terminal_manager").show()
    return true -- terminal_manager focuses its own window; nothing more to do
  end,
})

-- ── dap (nvim-dap-ui layout) ───────────────────────────────────────────────────
-- dapui manages scopes/breakpoints/stacks/watches/repl/console as ONE layout,
-- fully decoupled from the debug session — closing/opening it never touches
-- the adapter/session. singleton for the same reason as managed_terminal.
local DAPUI_FILETYPES = {
  dapui_scopes = true,
  dapui_breakpoints = true,
  dapui_stacks = true,
  dapui_watches = true,
  dapui_console = true,
  dapui_hover = true,
  dap_repl = true,
}
M.register({
  name = "dap",
  singleton = true,
  detect = function(_win, buf)
    return DAPUI_FILETYPES[vim.bo[buf].filetype] == true
  end,
  capture = function()
    return {}
  end,
  label = function()
    return "DAP UI"
  end,
  hide = function()
    local ok, dapui = pcall(require, "dapui")
    if not ok then
      return false
    end
    dapui.close()
    return true
  end,
  restore = function()
    local ok, dapui = pcall(require, "dapui")
    if not ok then
      return false
    end
    dapui.open()
    return true
  end,
})

-- ── overseer task list panel ──────────────────────────────────────────────────
-- The task list is a dedicated, overseer-managed window (filetype OverseerList).
-- Task execution lives on the task object, not the window, so hide/restore
-- here only ever touches the panel. A task's OverseerFloat *output* window is
-- an ordinary float with an ordinary buffer and is handled by the generic
-- provider below — overseer keeps no extra state tied to that window.
M.register({
  name = "overseer_panel",
  singleton = true,
  detect = function(_win, buf)
    return vim.bo[buf].filetype == "OverseerList"
  end,
  capture = function()
    return {}
  end,
  label = function()
    return "Overseer task list"
  end,
  hide = function()
    local ok, overseer = pcall(require, "overseer")
    if ok then
      pcall(overseer.close)
    end
    return ok
  end,
  restore = function()
    local ok, overseer = pcall(require, "overseer")
    if ok then
      pcall(overseer.open)
    end
    return ok
  end,
})

-- ── quickfix / location list ──────────────────────────────────────────────────
-- The list contents live independently of the window (Vim's qf/loc lists);
-- :copen / :lopen re-attach to the SAME list rather than needing us to carry
-- the buffer, and correctly re-establish the window-scoped loclist link that
-- a plain nvim_win_set_buf would not.
M.register({
  name = "quickfix",
  detect = function(_win, buf)
    return vim.bo[buf].buftype == "quickfix"
  end,
  capture = function(win)
    local info = vim.fn.getwininfo(win)[1]
    return { loclist = info ~= nil and info.loclist == 1 }
  end,
  label = function(meta)
    return meta.loclist and "Location List" or "Quickfix"
  end,
  hide = function(win)
    return (pcall(vim.api.nvim_win_hide, win))
  end,
  restore = function(meta)
    vim.cmd(meta.loclist and "lopen" or "copen")
    return true
  end,
})

-- ── generic (catch-all: terminals, help, floats, plain splits) ───────────────
-- Must be registered LAST. Operates directly on nvim_win_hide / nvim_open_win
-- / nvim_win_set_buf — verified (see tests/) to preserve terminal jobs because
-- it never touches the buffer, only the window.
local function is_float(win)
  return vim.api.nvim_win_get_config(win).relative ~= ""
end

M.register({
  name = "generic",
  detect = function()
    return true
  end,
  capture = function(win, buf)
    local float = is_float(win)
    local meta = {
      buf = buf,
      float = float,
      buftype = vim.bo[buf].buftype,
      filetype = vim.bo[buf].filetype,
      bufname = vim.api.nvim_buf_get_name(buf),
      view = vim.api.nvim_win_call(win, vim.fn.winsaveview),
      cwd = vim.fn.getcwd(win),
    }
    if float then
      local cfg = vim.api.nvim_win_get_config(win)
      meta.win_config = {
        relative = cfg.relative,
        row = cfg.row,
        col = cfg.col,
        width = cfg.width,
        height = cfg.height,
        anchor = cfg.anchor,
        border = cfg.border,
        zindex = cfg.zindex,
        style = cfg.style,
        title = cfg.title,
        title_pos = cfg.title_pos,
        footer = cfg.footer,
        footer_pos = cfg.footer_pos,
      }
    else
      -- Split orientation is approximated, not reconstructed from the window
      -- tree: a full-width window is treated as a horizontal split, anything
      -- narrower as vertical. Robust approximation beats a brittle attempt at
      -- perfectly replaying an arbitrary split layout (see README notes).
      meta.split = {
        vertical = vim.api.nvim_win_get_width(win) < vim.o.columns,
        width = vim.api.nvim_win_get_width(win),
        height = vim.api.nvim_win_get_height(win),
      }
    end
    return meta
  end,
  label = function(meta)
    if meta.buftype == "terminal" then
      return "Terminal"
    elseif meta.buftype == "help" then
      return "Help — " .. (vim.fn.fnamemodify(meta.bufname, ":t"):gsub("%.txt$", ""))
    elseif meta.bufname ~= "" then
      return vim.fn.fnamemodify(meta.bufname, ":t")
    end
    return meta.filetype ~= "" and meta.filetype or "[No Name]"
  end,
  hide = function(win)
    return (pcall(vim.api.nvim_win_hide, win))
  end,
  restore = function(meta)
    if not vim.api.nvim_buf_is_valid(meta.buf) then
      return nil
    end
    local win
    if meta.win_config then
      -- Re-clamp geometry to the CURRENT editor size so a float hidden
      -- before a resize doesn't reappear off-screen (see README limitations
      -- for what this does and doesn't guarantee).
      local cols = vim.o.columns
      local rows = vim.o.lines - vim.o.cmdheight - 1
      local wc = vim.deepcopy(meta.win_config)
      wc.width = math.max(1, math.min(wc.width, cols - 2))
      wc.height = math.max(1, math.min(wc.height, rows - 2))
      if wc.relative == "editor" then
        wc.row = math.max(0, math.min(wc.row, math.max(0, rows - wc.height)))
        wc.col = math.max(0, math.min(wc.col, math.max(0, cols - wc.width)))
      end
      local ok, result = pcall(vim.api.nvim_open_win, meta.buf, true, wc)
      if not ok then
        return nil
      end
      win = result
    else
      vim.cmd(meta.split.vertical and "botright vsplit" or "botright split")
      win = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(win, meta.buf)
      if meta.split.vertical then
        pcall(vim.api.nvim_win_set_width, win, meta.split.width)
      else
        pcall(vim.api.nvim_win_set_height, win, meta.split.height)
      end
    end
    pcall(vim.api.nvim_win_call, win, function()
      vim.fn.winrestview(meta.view)
    end)
    return win
  end,
  terminate = function(meta)
    if vim.api.nvim_buf_is_valid(meta.buf) then
      return (pcall(vim.api.nvim_buf_delete, meta.buf, { force = true }))
    end
    return false
  end,
})

return M
