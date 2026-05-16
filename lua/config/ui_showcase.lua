-- =============================================================================
--  config/ui_showcase.lua  ·  Neovim 0.12+ Feature Showcases
-- =============================================================================
-- This module contains demonstration commands for new Neovim 0.12 APIs.
-- They are separated from core config to keep the visual layer clean.

local M = {}

-- =============================================================================
--  FLOATING WINDOW WITH STATUSLINE  (0.12-new)
-- =============================================================================
local function open_info_float()
  local buf = vim.api.nvim_create_buf(false, true) -- scratch buffer
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "  Neovim 0.12 Info Float",
    "",
    "  Diagnostic: " .. vim.diagnostic.status(),
    "  Progress  : " .. vim.ui.progress_status(),
    "",
    "  Press q to close.",
  })

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = 48,
    height = 8,
    row = math.floor((vim.o.lines - 8) / 2),
    col = math.floor((vim.o.columns - 48) / 2),
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
--  LUA API SHOWCASES
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
  local files = { "init.lua", "archive.tar.gz", "no_ext", ".hidden" }
  for _, f in ipairs(files) do
    vim.notify(f .. " → ext: '" .. (vim.fs.ext(f) or "nil") .. "'", vim.log.levels.INFO)
  end
end

local function version_example()
  local r1 = vim.version.range(">=0.11.0 <1.0.0")
  local r2 = vim.version.range(">=0.12.0 <0.13.0")
  vim.notify("Range 1: " .. tostring(r1), vim.log.levels.INFO)
  vim.notify("Range 2: " .. tostring(r2), vim.log.levels.INFO)
  local intersection = vim.version.intersect(r1, r2)
  vim.notify("Intersection: " .. tostring(intersection), vim.log.levels.INFO)
  local current = vim.version()
  vim.notify("nvim " .. tostring(current) .. " in r2? " .. tostring(r2:has(current)), vim.log.levels.INFO)
end

local function iter_example()
  local nums = vim.iter({ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 })
  local result = nums
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
  vim.hl.range(buf, vim.api.nvim_create_namespace("demo_hl"), "Search", { line, 0 }, { line, -1 }, { timeout = 500 })
  vim.defer_fn(function()
    vim.hl.range(
      buf,
      vim.api.nvim_create_namespace("demo_hl2"),
      "IncSearch",
      { line, 0 },
      { line, -1 },
      { timeout = 500 }
    )
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

function M.setup()
  vim.api.nvim_create_user_command("NvimInfo", open_info_float, { desc = "[0.12] Show status float" })
  vim.api.nvim_create_user_command("FloatToTab", function()
    local wins = vim.api.nvim_tabpage_list_wins(0)
    local float_win = nil
    for _, w in ipairs(wins) do
      if vim.api.nvim_win_get_config(w).relative ~= "" then
        float_win = w
        break
      end
    end
    if not float_win then
      vim.notify("No float found", vim.log.levels.WARN)
      return
    end
    vim.cmd("tabnew")
    local new_tab = vim.api.nvim_get_current_tabpage()
    vim.api.nvim_win_set_config(float_win, { relative = "editor", tabnr = new_tab })
  end, { desc = "[0.12] Move float to new tab" })

  vim.api.nvim_create_user_command("DiffExample", show_diff_example, { desc = "[0.12] vim.text.diff() demo" })
  vim.api.nvim_create_user_command("UniqueExample", unique_example, { desc = "[0.12] vim.list.unique() demo" })
  vim.api.nvim_create_user_command("BisectExample", bisect_example, { desc = "[0.12] vim.list.bisect() demo" })
  vim.api.nvim_create_user_command("FsExtExample", fs_ext_example, { desc = "[0.12] vim.fs.ext() demo" })
  vim.api.nvim_create_user_command("VersionExample", version_example, { desc = "[0.12] vim.version demo" })
  vim.api.nvim_create_user_command("IterExample", iter_example, { desc = "[0.12] Iter demo" })
  vim.api.nvim_create_user_command("JsonExample", json_example, { desc = "[0.12] vim.json demo" })
  vim.api.nvim_create_user_command("HlRangeDemo", hl_range_example, { desc = "[0.12] vim.hl.range() demo" })
  vim.api.nvim_create_user_command("ProgressDemo", progress_demo, { desc = "[0.12] nvim_echo() progress demo" })

  vim.keymap.set("n", "<leader>ni", open_info_float, { desc = "[0.12] Open Neovim info float" })
end

return M
