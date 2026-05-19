-- =============================================================================
-- lua/plugins/overseer.lua
-- Production-grade overseer.nvim configuration using vim.pack (Neovim 0.12+)
-- Target stack: Go · JavaScript · TypeScript · Angular · Node.js · pnpm/npm
-- OS: Windows
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Package registration (vim.pack native, no lazy.nvim)
-- ---------------------------------------------------------------------------
vim.pack.add({
  { src = "https://github.com/stevearc/overseer.nvim" },
  -- Optional but recommended integrations (comment out if not needed)
  -- { src = "https://github.com/rcarriga/nvim-notify" }, -- rich notifications
  -- { src = "https://github.com/nvim-telescope/telescope.nvim" }, -- telescope picker
  -- { src = "https://github.com/mfussenegger/nvim-dap" },         -- DAP integration
})

-- ---------------------------------------------------------------------------
-- 2. Guard: only configure after the plugin is available
-- ---------------------------------------------------------------------------
local ok, overseer = pcall(require, "overseer")
if not ok then
  vim.notify("[overseer] Plugin not loaded – run :PackUpdate and restart.", vim.log.levels.WARN)
  return
end

-- ---------------------------------------------------------------------------
-- 4. Core overseer.setup()
-- ---------------------------------------------------------------------------
overseer.setup({
  -- ── Strategy ─────────────────────────────────────────────────────────────
  -- "terminal" uses a real :terminal buffer (works great on Windows cmd/pwsh)
  strategy = {
    "toggleterm",
    -- Fallback to built-in terminal if toggleterm is not installed:
    -- "terminal",
    direction = "horizontal",
    auto_scroll = true,
    quit_on_exit = "never",
  },

  -- ── Templates ─────────────────────────────────────────────────────────────
  -- Built-in template providers + our custom ones (auto-discovered by dir)
  templates = {
    "builtin", -- vscode tasks.json, make, cargo, tox, …
    "user.go", -- lua/overseer/template/go/
    "user.node", -- lua/overseer/template/node/
    "user.angular", -- lua/overseer/template/angular/
  },

  -- ── Auto-detection ────────────────────────────────────────────────────────
  auto_detect_success_color = true,

  -- ── Task list UI ──────────────────────────────────────────────────────────
  task_list = {
    default_detail = 1,
    max_width = { 100, 0.4 },
    min_width = { 40, 0.2 },
    width = nil,
    max_height = { 15, 0.25 },
    min_height = 8,
    separator = "─",
    direction = "bottom", -- panel sits at the bottom
    bindings = {
      ["?"] = "ShowHelp",
      ["<CR>"] = "RunAction",
      ["<C-e>"] = "Edit",
      ["o"] = "Open",
      ["<C-v>"] = "OpenVsplit",
      ["<C-s>"] = "OpenSplit",
      ["<C-f>"] = "OpenFloat",
      ["<C-q>"] = "OpenQuickfix",
      ["p"] = "TogglePreview",
      ["<C-l>"] = "IncreaseDetail",
      ["<C-h>"] = "DecreaseDetail",
      ["L"] = "IncreaseAllDetail",
      ["H"] = "DecreaseAllDetail",
      ["["] = "DecreaseWidth",
      ["]"] = "IncreaseWidth",
      ["{"] = "PrevTask",
      ["}"] = "NextTask",
      ["<C-k>"] = "ScrollOutputUp",
      ["<C-j>"] = "ScrollOutputDown",
      ["q"] = "Close",
    },
  },

  -- ── Floating task output window ───────────────────────────────────────────
  task_win = {
    max_width = 0.9,
    min_width = { 80, 0.5 },
    max_height = 0.9,
    min_height = { 10, 0.2 },
    padding = 2,
    border = "rounded", -- rounded borders everywhere
    win_opts = {
      winblend = 0,
      winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder",
    },
  },

  -- ── Form / editor ─────────────────────────────────────────────────────────
  form = {
    border = "rounded",
    zindex = 40,
    min_width = 80,
    max_width = 0.9,
    min_height = 10,
    max_height = 0.9,
    win_opts = { winblend = 0 },
  },
  confirm = {
    border = "rounded",
    zindex = 40,
    min_width = 20,
    max_width = 0.5,
    min_height = 6,
    max_height = 0.9,
    win_opts = { winblend = 0 },
  },

  -- ── Status icons (Nerd Font) ──────────────────────────────────────────────
  task_list_highlights = {
    -- per-status row highlights – tweak to match your colourscheme
  },

  -- ── Component aliases ─────────────────────────────────────────────────────
  -- Short-hand names used inside template `components` tables.
  component_aliases = {
    -- All tasks get these defaults automatically
    default = {
      "on_exit_set_status",
      { "on_complete_notify", system = "unfocused" },
      "on_complete_dispose",
    },
    -- Long-running (persistent) tasks keep running and notify on crash
    default_persist = {
      "on_exit_set_status",
      { "on_complete_notify", system = "unfocused" },
    },
    -- Tasks that should populate the quickfix list on completion
    default_quickfix = {
      "on_exit_set_status",
      { "on_complete_notify", system = "unfocused" },
      "on_complete_dispose",
      { "on_output_quickfix", open_on_exit = "failure", set_diagnostics = true },
    },
  },

  -- ── Diagnostics ───────────────────────────────────────────────────────────
  -- Populated automatically by templates that use on_output_parse +
  -- on_output_quickfix with set_diagnostics = true.

  -- ── DAP integration ───────────────────────────────────────────────────────
  dap = true, -- enable DAP task provider when nvim-dap present

  -- ── VSCode tasks.json ─────────────────────────────────────────────────────
  -- Handled automatically by the "builtin" template provider above.

  -- ── Log level ─────────────────────────────────────────────────────────────
  log = {
    { type = "echo", level = vim.log.levels.WARN },
    { type = "file", filename = "overseer.log", level = vim.log.levels.DEBUG },
  },
})

-- ---------------------------------------------------------------------------
-- 5. Telescope integration (graceful – works when telescope is absent)
-- ---------------------------------------------------------------------------
local has_telescope, _ = pcall(require, "telescope")
if has_telescope then
  pcall(require, "telescope").load_extension("overseer")
end

-- ---------------------------------------------------------------------------
-- 6. Persistent task list  (save/restore across sessions)
-- ---------------------------------------------------------------------------
-- Overseer serialises tasks automatically via its session support.
-- Hook into VimLeavePre / VimEnter to persist.
local session_file = vim.fn.stdpath("data") .. "/overseer_session.json"

vim.api.nvim_create_autocmd("VimLeavePre", {
  group = vim.api.nvim_create_augroup("OverseerSession", { clear = true }),
  callback = function()
    overseer.save_task_bundle("session", nil, { on_conflict = "replace" })
  end,
  desc = "Persist overseer task list on exit",
})

-- ── Reload on startup (manual – call :OverseerLoadBundle session) ──────────
-- Auto-load is intentionally omitted to avoid stale tasks from previous dirs.

-- ---------------------------------------------------------------------------
-- 7. Restart-on-save support
-- ---------------------------------------------------------------------------
-- Any template that sets  metadata.restart_on_save = true  will be restarted
-- when the relevant filetype is written.

local restart_augroup = vim.api.nvim_create_augroup("OverseerRestartOnSave", { clear = true })

vim.api.nvim_create_autocmd("BufWritePost", {
  group = restart_augroup,
  callback = function()
    for _, task in ipairs(overseer.list_tasks({ recent_first = true })) do
      if task.metadata and task.metadata.restart_on_save then
        overseer.run_action(task, "restart")
      end
    end
  end,
  desc = "Restart overseer tasks marked restart_on_save on BufWrite",
})

-- ---------------------------------------------------------------------------
-- 8. Task notifications via vim.notify (works with nvim-notify if installed)
-- ---------------------------------------------------------------------------
-- Already handled by the `on_complete_notify` component alias above.
-- Optionally upgrade all notifications to nvim-notify:
local has_notify, nvim_notify = pcall(require, "notify")
if has_notify then
  vim.notify = nvim_notify
end

-- ---------------------------------------------------------------------------
-- 9. Keymaps
-- ---------------------------------------------------------------------------
local map = function(lhs, rhs, desc)
  vim.keymap.set("n", lhs, rhs, { noremap = true, silent = true, desc = desc })
end

-- ── Primary workflow ──────────────────────────────────────────────────────
map("<leader>or", function()
  if has_telescope then
    vim.cmd("Telescope overseer")
  else
    overseer.run_template()
  end
end, "Overseer: Run task")

map("<leader>ot", "<cmd>OverseerToggle<CR>", "Overseer: Toggle panel")
map("<leader>oo", "<cmd>OverseerQuickAction open<CR>", "Overseer: Open task output")

map("<leader>ol", function()
  local tasks = overseer.list_tasks({ recent_first = true })
  if vim.tbl_isempty(tasks) then
    vim.notify("No recent overseer task", vim.log.levels.INFO)
    return
  end
  overseer.run_action(tasks[1], "restart")
end, "Overseer: Rerun last task")

map("<leader>ob", "<cmd>OverseerBuild<CR>", "Overseer: Task builder")

-- ── Task management ───────────────────────────────────────────────────────
map("<leader>oc", "<cmd>OverseerClose<CR>", "Overseer: Close panel")
map("<leader>od", "<cmd>OverseerDeleteBundle<CR>", "Overseer: Delete bundle")
map("<leader>os", "<cmd>OverseerSaveBundle<CR>", "Overseer: Save bundle")
map("<leader>oL", "<cmd>OverseerLoadBundle<CR>", "Overseer: Load bundle")
map("<leader>oq", "<cmd>OverseerQuickAction<CR>", "Overseer: Quick action")
map("<leader>oI", "<cmd>OverseerInfo<CR>", "Overseer: Info / debug")

-- ── Quickfix integration ──────────────────────────────────────────────────
map("<leader>oQ", function()
  local tasks = overseer.list_tasks({ recent_first = true })
  if not vim.tbl_isempty(tasks) then
    overseer.run_action(tasks[1], "open quickfix")
  end
end, "Overseer: Open quickfix for last task")

-- ---------------------------------------------------------------------------
-- 10. User commands  (extend the built-in :Overseer* commands)
-- ---------------------------------------------------------------------------
local cmd = vim.api.nvim_create_user_command

--- :OverseerRerunLast  – restart the most-recent task without a picker
cmd("OverseerRerunLast", function()
  local tasks = overseer.list_tasks({ recent_first = true })
  if vim.tbl_isempty(tasks) then
    vim.notify("No recent overseer task.", vim.log.levels.WARN)
    return
  end
  overseer.run_action(tasks[1], "restart")
end, { desc = "Restart the most recent overseer task" })

--- :OverseerKillAll  – stop every running task
cmd("OverseerKillAll", function()
  for _, task in ipairs(overseer.list_tasks()) do
    if task.status == "RUNNING" then
      task:stop()
    end
  end
  vim.notify("All running tasks stopped.", vim.log.levels.INFO)
end, { desc = "Stop all running overseer tasks" })

--- :OverseerRunGo  – quick shortcut for Go template picker
cmd("OverseerRunGo", function()
  overseer.run_template({ tags = { "go" } })
end, { desc = "Run an overseer Go task" })

--- :OverseerRunNode  – quick shortcut for Node/TS template picker
cmd("OverseerRunNode", function()
  overseer.run_task({ tags = { "node" } })
end, { desc = "Run an overseer Node/TS task" })

--- :OverseerRunAngular  – quick shortcut for Angular template picker
cmd("OverseerRunAngular", function()
  overseer.run_task({ tags = { "angular" } })
end, { desc = "Run an overseer Angular task" })

--- :OverseerSaveSession  – manually save bundle as "session"
cmd("OverseerSaveSession", function()
  overseer.save_task_bundle("session", nil, { on_conflict = "replace" })
  vim.notify("Overseer session saved.", vim.log.levels.INFO)
end, { desc = "Save all overseer tasks as 'session' bundle" })

--- :OverseerLoadSession  – manually restore "session" bundle
cmd("OverseerLoadSession", function()
  overseer.load_task_bundle("session")
end, { desc = "Load the 'session' overseer bundle" })

-- ---------------------------------------------------------------------------
-- 11. Which-key documentation
-- ---------------------------------------------------------------------------
local wk_ok, wk = pcall(require, "which-key")
if wk_ok then
  wk.add({
    { "<leader>o", group = "Tasks (Overseer)" },
  })
end

-- ---------------------------------------------------------------------------
-- 12. Status-line helper (expose for lualine / heirline etc.)
-- ---------------------------------------------------------------------------
-- Usage in lualine:
--   { require("overseer").task_list.status_str, ... }
-- or the dedicated lualine component:
--   require("lualine").setup { sections = { lualine_x = { "overseer" } } }
