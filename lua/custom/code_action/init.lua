-- lua/custom/code_action/init.lua
-- Public API for the code_action plugin.
--
-- Usage:
--   require("custom.code_action").setup()
--   require("custom.code_action").setup({
--     auto_apply_single = true,
--     picker  = { winblend = 8 },
--     keymaps = { filter = "<C-f>" },
--   })

local M = {}

-- ── Default config ────────────────────────────────────────────────────────────

---@class CodeActionConfig
M.config = {
  ---Milliseconds to wait for all LSP clients before giving up.
  timeout_ms = 3000,

  ---Skip the picker and apply immediately when only one action exists.
  auto_apply_single = false,

  picker = {
    ---Maximum picker width as a fraction of &columns.
    max_width_pct = 0.50,
    ---Minimum picker width in columns.
    min_width = 48,
    ---Maximum picker height as a fraction of &lines.
    max_height_pct = 0.45,
    ---Window transparency (0 = opaque).
    winblend = 0,
  },

  preview = {
    ---Preview width as a fraction of &columns.
    width_pct = 0.52,
    ---Preview height as a fraction of &lines.
    height_pct = 0.70,
    ---Minimum preview width in columns.
    min_width = 56,
    ---Maximum preview width in columns.
    max_width = 120,
    ---Minimum preview height in rows.
    min_height = 12,
    ---Window transparency (0 = opaque).
    winblend = 0,
    ---When true, start in diff mode when a workspace edit is available.
    show_diff = false,
    ---When true, show a live buffer-diff panel (tiny-code-action Buffer Picker style).
    buf_preview = true,
    ---When true, open the preview window by default.
    auto_open = false,
  },

  ---@type { use_icons: boolean }
  kinds = {
    use_icons = true,
  },

  keymaps = {
    apply = "<CR>",
    close = { "<Esc>", "q" },
    preview = { "K", "p" },
    focus_preview = "<C-w>p",
    diff_mode = "d",
    nav_down = { "j", "<Down>", "<C-n>", "<Tab>" },
    nav_up = { "k", "<Up>", "<C-p>", "<S-Tab>" },
    go_first = "gg",
    go_last = "G",
    page_down = "<C-d>",
    page_up = "<C-u>",
    filter = "/",
  },
}

-- ── Public API ────────────────────────────────────────────────────────────────

---Open the code action picker.
---@param opts table|nil
---  opts.use_visual_range  boolean  force visual-range mode (default: auto-detect)
---  opts.bufnr             integer  buffer to query (default: current)
---  opts.open_preview      boolean  open preview pane immediately
function M.open(opts)
  opts = opts or {}

  local source_win = vim.api.nvim_get_current_win()
  local source_buf = opts.bufnr or vim.api.nvim_get_current_buf()
  local source_cursor = vim.api.nvim_win_get_cursor(source_win)
  local mode = vim.fn.mode()

  local use_visual = opts.use_visual_range
  if use_visual == nil then
    use_visual = mode:find("[vV\22]") ~= nil
  end

  local visual_marks = nil
  if use_visual then
    local v_pos = vim.fn.getpos("v")
    local cur_pos = vim.api.nvim_win_get_cursor(0)
    local sp = { v_pos[2], v_pos[3] }
    local ep = { cur_pos[1], cur_pos[2] + 1 }
    if sp[1] > ep[1] or (sp[1] == ep[1] and sp[2] > ep[2]) then
      sp, ep = ep, sp
    end
    visual_marks = { sp, ep }
    local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
    vim.api.nvim_feedkeys(esc, "nx", false)
  end

  local lsp_mod = require("custom.code_action.lsp")
  local window = require("custom.code_action.window")

  local open_preview = opts.open_preview
  if open_preview == nil then
    open_preview = M.config.preview.auto_open == true
  end

  lsp_mod.request(source_buf, source_win, nil, visual_marks, M.config.timeout_ms, function(items)
    if M.config.auto_apply_single and #items == 1 then
      lsp_mod.apply(items[1])
      return
    end

    window.open(items, source_win, source_buf, source_cursor, {
      open_preview = open_preview,
      config = M.config,
    })
  end)
end

---Reset the internal is_open guard in case an unhandled error left it stuck.
function M.reset()
  require("custom.code_action.window").reset()
end

---One-time setup: merge user options, configure sub-modules, register
---highlight groups, default keymaps, and user commands.
---Safe to call multiple times (later calls perform a deep-merge).
---@param user_opts CodeActionConfig|nil
function M.setup(user_opts)
  if user_opts then
    M.config = vim.tbl_deep_extend("force", M.config, user_opts)
  end

  require("custom.code_action.kinds").setup(M.config.kinds)
  require("custom.code_action.highlight").setup()

  -- ── Default keymaps ───────────────────────────────────────────────────────

  local map = vim.keymap.set
  map("n", "<leader>ca", M.open, { desc = "LSP: Code Action" })
  map("x", "<leader>ca", M.open, { desc = "LSP: Code Action" })
  map("n", "<leader>cA", function()
    M.open({ open_preview = true })
  end, { desc = "LSP: Code Action (preview)" })

  -- ── User commands ─────────────────────────────────────────────────────────

  vim.api.nvim_create_user_command("CodeActionMenu", function(cmd_opts)
    M.open({ use_visual_range = cmd_opts.range > 0 })
  end, {
    desc = "Open a floating, cursor-navigable code action picker",
    range = true,
  })

  vim.api.nvim_create_user_command("CodeActionMenuPreview", function(cmd_opts)
    M.open({ use_visual_range = cmd_opts.range > 0, open_preview = true })
  end, {
    desc = "Open the code action picker with preview pane open",
    range = true,
  })

  vim.api.nvim_create_user_command("CodeActionMenuReset", function()
    M.reset()
    vim.notify("Code action menu state reset", vim.log.levels.INFO, { title = "Code Actions" })
  end, {
    desc = "Reset code action menu state (use if the menu gets stuck)",
  })
end

return M
