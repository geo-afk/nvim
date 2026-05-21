-- =============================================================================
--  config/ui_showcase.lua  ·  Neovim 0.12+ Feature Showcases
-- =============================================================================

local M = {}

-- =============================================================================
--  Floating window with per-window statusline (0.12-new)
-- =============================================================================

local function open_info_float()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "  Neovim 0.12 Info Float",
    "",
    "  Diagnostic: " .. vim.diagnostic.status(),
    "  Progress  : " .. vim.ui.progress_status(),
    "",
    "  Press q to close.",
  })

  local lines = vim.o.lines
  local cols = vim.o.columns
  local H, W = 8, 48

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = W,
    height = H,
    row = math.floor((lines - H) / 2),
    col = math.floor((cols - W) / 2),
    border = "rounded",
    title = " Nvim 0.12 Status ",
    title_pos = "center",
    statusline = " %-10{v:lua.vim.diagnostic.status()} %=%{strftime('%H:%M')} ",
    style = "minimal",
  })

  vim.wo[win].wrap = false
  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf, nowait = true })
end

-- =============================================================================
--  API demos
-- =============================================================================

local function show_diff_example()
  local a = "hello world\nfoo bar\n"
  local b = "hello Neovim\nfoo bar\nbaz\n"
  local diff = vim.text.diff(a, b, { result_type = "unified" })
  vim.notify(tostring(diff), vim.log.levels.INFO)
end

local function unique_example()
  local items = { "lua", "python", "lua", "rust", "python", "go" }
  local unique = vim.list.unique(items)
  vim.notify("unique: " .. table.concat(unique, ", "), vim.log.levels.INFO)
end

local function bisect_example()
  local sorted = { 1, 3, 5, 7, 9, 11 }
  local idx = vim.list.bisect(sorted, 6)
  vim.notify("bisect([1,3,5,7,9,11], 6) → " .. idx, vim.log.levels.INFO)
end

local function fs_ext_example()
  for _, f in ipairs({ "init.lua", "archive.tar.gz", "no_ext", ".hidden" }) do
    vim.notify(f .. " → ext: '" .. (vim.fs.ext(f) or "nil") .. "'", vim.log.levels.INFO)
  end
end

local function version_example()
  local r1 = vim.version.range(">=0.11.0 <1.0.0")
  local r2 = vim.version.range(">=0.12.0 <0.13.0")
  local cur = vim.version()
  vim.notify("Range 1: " .. tostring(r1), vim.log.levels.INFO)
  vim.notify("Range 2: " .. tostring(r2), vim.log.levels.INFO)
  vim.notify("Intersection: " .. tostring(vim.version.intersect(r1, r2)), vim.log.levels.INFO)
  vim.notify("nvim " .. tostring(cur) .. " in r2? " .. tostring(r2:has(cur)), vim.log.levels.INFO)
end

local function iter_example()
  local result = vim
    .iter({ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 })
    :skip(function(v)
      return v < 4
    end)
    :take(function(v)
      return v <= 7
    end)
    :totable()
  vim.notify("Iter result: " .. vim.inspect(result), vim.log.levels.INFO)
end

local function json_example()
  local jsonc = '{ /* greeting */ "hello": "world", "n": 42 }'
  local decoded = vim.json.decode(jsonc, { skip_comments = true })
  local pretty = vim.json.encode(decoded, { indent = "2", sort_keys = true })
  vim.notify("Pretty JSON:\n" .. pretty, vim.log.levels.INFO)
end

local function hl_range_example()
  local buf = vim.api.nvim_get_current_buf()
  local line = vim.api.nvim_win_get_cursor(0)[1] - 1
  local ns1 = vim.api.nvim_create_namespace("demo_hl")
  local ns2 = vim.api.nvim_create_namespace("demo_hl2")
  vim.hl.range(buf, ns1, "Search", { line, 0 }, { line, -1 }, { timeout = 500 })
  vim.defer_fn(function()
    vim.hl.range(buf, ns2, "IncSearch", { line, 0 }, { line, -1 }, { timeout = 500 })
  end, 600)
end

local function progress_demo()
  local steps = { "Fetching…", "Parsing…", "Done!" }
  for i, msg in ipairs(steps) do
    vim.defer_fn(function()
      vim.api.nvim_echo({ { msg, "Comment" } }, false, {
        id = "demo_progress",
        kind = "progress",
        title = "Demo Task",
        status = i < #steps and "running" or "success",
        percent = math.floor((i / #steps) * 100),
      })
    end, (i - 1) * 800)
  end
end

local function float_to_tab()
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_config(w).relative ~= "" then
      vim.cmd("tabnew")
      pcall(vim.api.nvim_win_set_config, w, {
        relative = "editor",
        tabnr = vim.api.nvim_get_current_tabpage(),
      })
      return
    end
  end
  vim.notify("No float found", vim.log.levels.WARN)
end

-- =============================================================================
--  Setup
-- =============================================================================

function M.setup()
  local cmds = {
    { "NvimInfo", open_info_float, "[0.12] Show status float" },
    { "FloatToTab", float_to_tab, "[0.12] Move float to new tab" },
    { "DiffExample", show_diff_example, "[0.12] vim.text.diff() demo" },
    { "UniqueExample", unique_example, "[0.12] vim.list.unique() demo" },
    { "BisectExample", bisect_example, "[0.12] vim.list.bisect() demo" },
    { "FsExtExample", fs_ext_example, "[0.12] vim.fs.ext() demo" },
    { "VersionExample", version_example, "[0.12] vim.version demo" },
    { "IterExample", iter_example, "[0.12] Iter demo" },
    { "JsonExample", json_example, "[0.12] vim.json demo" },
    { "HlRangeDemo", hl_range_example, "[0.12] vim.hl.range() demo" },
    { "ProgressDemo", progress_demo, "[0.12] nvim_echo() progress demo" },
  }

  for _, cmd in ipairs(cmds) do
    vim.api.nvim_create_user_command(cmd[1], cmd[2], { desc = cmd[3] })
  end

  vim.keymap.set("n", "<leader>ni", open_info_float, { desc = "[0.12] Open Neovim info float" })
end

return M
