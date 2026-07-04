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
  strategy = {
    "toggleterm",
    direction = "float",
    auto_scroll = true,
    quit_on_exit = "never",
  },

  -- ── Templates ─────────────────────────────────────────────────────────────
  templates = {
    "builtin",
    "user.go",
    "user.node",
    "user.angular",
  },

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
    direction = "bottom",
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
      ["q"] = "Close", -- already present, unchanged
    },
  },

  -- ── Floating task output window ───────────────────────────────────────────
  task_win = {
    -- ~50% width, ~60% height (fractions clamp to screen %)
    max_width = 0.5,
    min_width = { 40, 0.3 },
    max_height = 0.6,
    min_height = { 8, 0.15 },
    padding = 2,
    border = "rounded",
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

  task_list_highlights = {},

  component_aliases = {
    default = {
      "on_exit_set_status",
      { "on_complete_notify", system = "unfocused" },
      "on_complete_dispose",
    },
    default_persist = {
      "on_exit_set_status",
      { "on_complete_notify", system = "unfocused" },
    },
    default_quickfix = {
      "on_exit_set_status",
      { "on_complete_notify", system = "unfocused" },
      "on_complete_dispose",
      { "on_output_quickfix", open_on_exit = "failure", set_diagnostics = true },
    },
  },

  dap = true,

  log = {
    { type = "echo", level = vim.log.levels.WARN },
    { type = "file", filename = "overseer.log", level = vim.log.levels.DEBUG },
  },
})

-- q or <Esc> to close the task_win float (task_win has no bindings config; do it via autocmd)
vim.api.nvim_create_autocmd("FileType", {
  pattern = "OverseerFloat",
  callback = function(ev)
    vim.keymap.set("n", "q", "<C-w>c", { buffer = ev.buf, silent = true })
    vim.keymap.set("n", "<Esc>", "<C-w>c", { buffer = ev.buf, silent = true })
  end,
})
-- ---------------------------------------------------------------------------
-- 5. Telescope integration (graceful – works when telescope is absent)
-- ---------------------------------------------------------------------------
local has_telescope, telescope = pcall(require, "telescope")
if has_telescope then
  telescope.load_extension("overseer")
end
-- ---------------------------------------------------------------------------
-- 6. Persistent task list  (save/restore across sessions)
-- ---------------------------------------------------------------------------
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
    overseer.run_task({})
  end
end, "Overseer: Run task")

map("<leader>ot", "<cmd>OverseerToggle<CR>", "Overseer: Toggle panel")
map("<leader>oo", function()
  local tasks = overseer.list_tasks({ recent_first = true })
  if not vim.tbl_isempty(tasks) then
    overseer.run_action(tasks[1], "open float")
  else
    vim.notify("No recent overseer task", vim.log.levels.INFO)
  end
end, "Overseer: Open task output")

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
map("<leader>oq", "<cmd>OverseerTaskAction<CR>", "Overseer: Task action")
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
  overseer.run_task({
    tags = { "go" },
  })
end, {
  desc = "Run an overseer Go task",
})

cmd("OverseerRunNode", function()
  overseer.run_task({
    tags = { "node" },
  })
end, {
  desc = "Run an overseer Node/TS task",
})

cmd("OverseerRunAngular", function()
  overseer.run_task({
    tags = { "angular" },
  })
end, {
  desc = "Run an overseer Angular task",
})

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

--   { require("overseer").task_list.status_str, ... }
