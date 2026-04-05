-- lua/code_action/init.lua
-- Public API for the code_action plugin.
--
-- Usage (in init.lua / lazy.nvim spec):
--
--   require("code_action").setup()
--
-- This sets up highlight groups, registers the <leader>ca keymap,
-- and creates the :CodeActionMenu user command.
--
-- Module structure
-- ────────────────
--   init.lua        ← you are here (public API + setup)
--   highlights.lua  ← HL group definitions & per-source colour palette
--   kinds.lua       ← LSP kind → icon / badge mapping
--   lsp.lua         ← async code-action request & action application
--   layout.lua      ← window geometry, title, and footer construction
--   renderer.lua    ← line builder, highlight applicator, virtual scrollbar
--   window.lua      ← float creation, keymaps, and lifecycle management

local M = {}

-- ── Visual-range helpers ────────────────────────────────────────────────────

---Build an LSP Range table from the current visual selection marks.
---Returns nil when no valid visual marks exist.
---@return table|nil
local function get_visual_range()
  local s = vim.fn.getpos("'<")
  local e = vim.fn.getpos("'>")
  if s[2] == 0 or e[2] == 0 then
    return nil
  end

  local sl, sc = s[2] - 1, math.max(s[3] - 1, 0)
  local el, ec = e[2] - 1, math.max(e[3] - 1, 0)

  if sl > el or (sl == el and sc > ec) then
    sl, el, sc, ec = el, sl, ec, sc
  end

  return {
    ["start"] = { line = sl, character = sc },
    ["end"] = { line = el, character = ec },
  }
end

---Return the visual selection as a pair of 1-indexed { row, col } positions.
---Returns nil, nil when no valid visual marks exist.
---@return integer[]|nil, integer[]|nil
local function get_visual_marks()
  local s = vim.fn.getpos("'<")
  local e = vim.fn.getpos("'>")
  if s[2] == 0 or e[2] == 0 then
    return nil, nil
  end

  local sp = { s[2], math.max(s[3] - 1, 0) }
  local ep = { e[2], math.max(e[3] - 1, 0) }

  if sp[1] > ep[1] or (sp[1] == ep[1] and sp[2] > ep[2]) then
    sp, ep = ep, sp
  end

  return sp, ep
end

-- ── Public API ───────────────────────────────────────────────────────────────

---Open the code action picker.
---
---@param opts table|nil
---  opts.use_visual_range  boolean   force visual-range mode (default: auto-detect)
---  opts.bufnr             integer   buffer to query (default: current)
function M.open(opts)
  opts = opts or {}

  -- Capture context NOW, before anything goes async or modes change.
  local source_win = vim.api.nvim_get_current_win()
  local source_buf = opts.bufnr or vim.api.nvim_get_current_buf()
  local source_cursor = vim.api.nvim_win_get_cursor(source_win)
  local mode = vim.fn.mode()

  local use_visual = opts.use_visual_range
  if use_visual == nil then
    use_visual = mode:find("[vV\22]") ~= nil
  end

  -- Exit visual mode so that '< '> marks are committed to the buffer
  -- before we read them.
  if use_visual then
    local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
    vim.api.nvim_feedkeys(esc, "nx", false)
  end

  local range = use_visual and get_visual_range() or nil
  local vstart, vend = use_visual and get_visual_marks() or nil, nil
  local visual_marks = (vstart and vend) and { vstart, vend } or nil

  local lsp = require("custom.code_action.lsp")
  local window = require("custom.code_action.window")

  lsp.request(source_buf, source_win, range, visual_marks, function(items)
    window.open(items, source_win, source_buf, source_cursor)
  end)
end

---One-time setup: register highlight groups, the default keymap, and the
---:CodeActionMenu user command.
---Call this once from your init.lua or plugin spec setup() hook.
---
---@param user_opts table|nil  (reserved for future per-user config)
function M.setup(user_opts)
  _ = user_opts -- reserved

  require("custom.code_action.highlight").setup()

  -- Default keymap (<leader>ca works in both normal and visual mode).
  vim.keymap.set({ "n", "x" }, "<leader>ca", function()
    M.open()
  end, {
    desc = "LSP: Code Action",
    silent = true,
  })

  -- User command (:CodeActionMenu, range-aware for visual-mode invocation).
  vim.api.nvim_create_user_command("CodeActionMenu", function(cmd_opts)
    M.open({ use_visual_range = cmd_opts.range > 0 })
  end, {
    desc = "Open a floating, cursor-navigable code action picker",
    range = true,
  })
end

return M
