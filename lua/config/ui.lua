-- =============================================================================
--  config/ui.lua  ·  Visual & UX layer
--
--  Covers:
--    • ui2 (experimental redesigned message/cmdline UI)
--    • nvim_open_win() with float statusline
--    • nvim_set_hl() partial update (update = true)
--    • vim.net.request() demo
--    • New Lua stdlib APIs (vim.list, vim.fs, vim.version, vim.text)
--    • vim.json improvements
--    • nvim_echo() progress messages
--    • Treesitter setup
--    • Gitsigns
--    • nvim-tree
-- =============================================================================

-- =============================================================================
--  UI2 – EXPERIMENTAL REDESIGNED MESSAGE / CMDLINE UI  (0.12-new)
-- =============================================================================
-- NEOVIM 0.11 → 0.12 COMPARISON:
--   0.11:  The message grid is monolithic; "Press ENTER" prompts are frequent.
--          Long command output requires scrolling through a temporary overlay.
--
--   0.12:  ui2 decouples messages from the core grid.  Benefits:
--            • No "Press ENTER" interruptions.
--            • Delays from W10 "Changing a readonly file" warnings are gone.
--            • Cmdline is highlighted as you type.
--            • Pager is a real buffer (scrollable, searchable with /).
--            • :restart / :connect work because the UI is detached from core.
--          Currently experimental – enable with the call below.

local ok_ui2 = pcall(function()
  require("vim._core.ui2").enable({
    enable = true,
    msg = {
      -- "cmd" = messages appear in cmdline area (default, less intrusive)
      -- "msg" = messages appear in a separate ephemeral floating window
      -- targets = "msg",
      targets = {
        [""] = "msg",
        empty = "cmd",
        bufwrite = "msg",
        confirm = "cmd",
        emsg = "pager",
        echo = "msg",
        echomsg = "msg",
        echoerr = "pager",
        completion = "cmd",
        list_cmd = "pager",
        lua_error = "pager",
        lua_print = "msg",
        progress = "pager",
        rpc_error = "pager",
        quickfix = "msg",
        search_cmd = "cmd",
        search_count = "cmd",
        shell_cmd = "pager",
        shell_err = "pager",
        shell_out = "pager",
        shell_ret = "msg",
        undo = "msg",
        verbose = "pager",
        wildlist = "cmd",
        wmsg = "msg",
        typed_cmd = "cmd",
      },
      cmd = {
        -- Maximum height of the expanded cmdline message area (fraction of win)
        height = 0.1,
      },
      dialog = {
        height = 0.4, -- dialog boxes
      },
      msg = {
        height = 0.3,
        timeout = 5000, -- ms before the ephemeral message disappears
      },
      pager = {
        height = 0.4, -- pager buffer height when viewing long output
      },
    },
  })
end)

if not ok_ui2 then
  vim.notify("ui2 is not available in this Neovim build; upgrade to 0.12+", vim.log.levels.WARN)
end

-- =============================================================================
--  FLOATING WINDOW WITH STATUSLINE  (0.12-new)
-- =============================================================================
-- [0.12-new] nvim_open_win() and nvim_win_set_config() now support a
--  'statusline' key for floating windows.
--  In 0.11, float windows had no native statusline – you had to fake it with
--  a bottom border character or a winbar.

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
    -- [0.12-new] Show a custom statusline inside the float:
    statusline = " %-10{v:lua.vim.diagnostic.status()} %=%{strftime('%H:%M')} ",
    style = "minimal",
  })

  vim.wo[win].wrap = false
  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf, nowait = true })
end

vim.api.nvim_create_user_command("NvimInfo", open_info_float, {
  desc = "[0.12] Show status float with native statusline in float",
})
vim.keymap.set("n", "<leader>ni", open_info_float, { desc = "[0.12] Open Neovim info float" })

-- =============================================================================
--  nvim_win_set_config() – MOVE FLOAT TO ANOTHER TABPAGE  (0.12-new)
-- =============================================================================
-- [0.12-new] Floating windows can now be moved to a different tabpage.
--  In 0.11 a float was always bound to the tabpage it was created in.
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
    vim.notify("No floating window in current tab", vim.log.levels.WARN)
    return
  end
  vim.cmd("tabnew")
  local new_tab = vim.api.nvim_get_current_tabpage()
  -- [0.12-new] move the float to the new tabpage:
  vim.api.nvim_win_set_config(float_win, { relative = "editor", tabnr = new_tab })
  vim.notify("Float moved to tab " .. new_tab, vim.log.levels.INFO)
end, { desc = "[0.12] Move the first float to a new tab" })

-- =============================================================================
--  LUA API NEW / CHANGED  (0.12-new)
-- =============================================================================

-- ── vim.text.diff()  [0.12-changed: renamed from vim.diff()] ──────────────────
-- In 0.11: vim.diff(a, b, opts)
-- In 0.12: vim.text.diff(a, b, opts)   (vim.diff is deprecated)
local function show_diff_example()
  local a = "hello world\nfoo bar\n"
  local b = "hello Neovim\nfoo bar\nbaz\n"
  -- [0.12] vim.text.diff replaces vim.diff:
  local diff = vim.text.diff(a, b, { result_type = "unified" })
  vim.notify(tostring(diff), vim.log.levels.INFO)
end
vim.api.nvim_create_user_command("DiffExample", show_diff_example, {
  desc = "[0.12] vim.text.diff() (renamed from vim.diff) demo",
})

-- ── vim.list.unique()  [0.12-new] ─────────────────────────────────────────────
-- In 0.11: no stdlib equivalent; needed table iteration or vim.fn.uniq().
local function unique_example()
  local items = { "lua", "python", "lua", "rust", "python", "go" }
  -- [0.12-new]:
  local unique = vim.list.unique(items)
  vim.notify("unique: " .. table.concat(unique, ", "), vim.log.levels.INFO)
end
vim.api.nvim_create_user_command("UniqueExample", unique_example, {
  desc = "[0.12] vim.list.unique() demo",
})

-- ── vim.list.bisect()  [0.12-new] ─────────────────────────────────────────────
local function bisect_example()
  local sorted = { 1, 3, 5, 7, 9, 11 }
  -- Binary search – returns insertion point:
  local idx = vim.list.bisect(sorted, 6)
  vim.notify("bisect([1,3,5,7,9,11], 6) → " .. idx, vim.log.levels.INFO)
end
vim.api.nvim_create_user_command("BisectExample", bisect_example, {
  desc = "[0.12] vim.list.bisect() demo",
})

-- ── vim.fs.ext()  [0.12-new] ──────────────────────────────────────────────────
-- In 0.11: vim.fn.fnamemodify(f, ":e") or manual string parsing.
-- In 0.12: vim.fs.ext() returns the LAST extension (handles .tar.gz etc.)
local function fs_ext_example()
  local files = { "init.lua", "archive.tar.gz", "no_ext", ".hidden" }
  for _, f in ipairs(files) do
    -- [0.12-new]:
    vim.notify(f .. " → ext: '" .. (vim.fs.ext(f) or "nil") .. "'", vim.log.levels.INFO)
  end
end
vim.api.nvim_create_user_command("FsExtExample", fs_ext_example, {
  desc = "[0.12] vim.fs.ext() demo",
})

-- ── vim.version.range() / vim.version.intersect()  [0.12-new/changed] ─────────
local function version_example()
  local r1 = vim.version.range(">=0.11.0 <1.0.0")
  local r2 = vim.version.range(">=0.12.0 <0.13.0")

  -- [0.12-changed] vim.version.range() can now be printed via tostring():
  vim.notify("Range 1: " .. tostring(r1), vim.log.levels.INFO)
  vim.notify("Range 2: " .. tostring(r2), vim.log.levels.INFO)

  -- [0.12-new] vim.version.intersect() computes the intersection:
  local intersection = vim.version.intersect(r1, r2)
  vim.notify("Intersection: " .. tostring(intersection), vim.log.levels.INFO)

  -- Check current Neovim against range:
  local current = vim.version()
  vim.notify("nvim " .. tostring(current) .. " in r2? " .. tostring(r2:has(current)), vim.log.levels.INFO)
end
vim.api.nvim_create_user_command("VersionExample", version_example, {
  desc = "[0.12] vim.version.range / intersect demo",
})

-- ── Iter:take() / Iter:skip() with predicates  [0.12-new] ────────────────────
local function iter_example()
  local nums = vim.iter({ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 })

  -- [0.12-new] Iter:skip() and Iter:take() now accept predicates:
  local result = nums
    :skip(function(v)
      return v < 4
    end) -- skip while v < 4
    :take(function(v)
      return v <= 7
    end) -- take while v <= 7
    :totable()

  vim.notify("Iter result: " .. vim.inspect(result), vim.log.levels.INFO)
end
vim.api.nvim_create_user_command("IterExample", iter_example, {
  desc = "[0.12] Iter:take/skip with predicates demo",
})

-- ── vim.json improvements  [0.12-new] ─────────────────────────────────────────
local function json_example()
  -- [0.12-new] skip_comments: allows JSON with // and /* */ comments
  local jsonc = '{ /* greeting */ "hello": "world", "n": 42 }'
  local decoded = vim.json.decode(jsonc, { skip_comments = true })

  -- [0.12-new] indent + sort_keys for pretty-print
  local pretty = vim.json.encode(decoded, { indent = "2", sort_keys = true })
  vim.notify("Pretty JSON:\n" .. pretty, vim.log.levels.INFO)
end
vim.api.nvim_create_user_command("JsonExample", json_example, {
  desc = "[0.12] vim.json encode/decode options demo",
})

-- ── vim.hl.range() multiple timed highlights  [0.12-new] ─────────────────────
-- [0.12-new] vim.hl.range() now allows multiple timed highlights on ranges.
local function hl_range_example()
  local buf = vim.api.nvim_get_current_buf()
  local line = vim.api.nvim_win_get_cursor(0)[1] - 1
  -- Highlight current line in two passes with different highlight groups:
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
vim.api.nvim_create_user_command("HlRangeDemo", hl_range_example, {
  desc = "[0.12] vim.hl.range() multiple timed highlights",
})

-- ── nvim_echo() with Progress  [0.12-new] ─────────────────────────────────────
local function progress_demo()
  -- [0.12-new] nvim_echo() can now create progress messages with `id`.
  --  Same id = update in-place; kind = "progress" triggers Progress event.
  local steps = { "Fetching…", "Parsing…", "Done!" }
  for i, msg in ipairs(steps) do
    vim.defer_fn(function()
      vim.api.nvim_echo({ { msg, "Comment" } }, false, {
        id = "demo_progress", -- [0.12-new] stable id for in-place update
        kind = "progress", -- [0.12-new] emits Progress event
        title = "Demo Task",
        status = i < #steps and "running" or "success",
        percent = math.floor((i / #steps) * 100),
      })
    end, (i - 1) * 800)
  end
end
vim.api.nvim_create_user_command("ProgressDemo", progress_demo, {
  desc = "[0.12] nvim_echo() progress message demo",
})
