-- nvim-cmdline/vim_ui.lua
-- Modern floating UI for vim.ui.input and vim.ui.select.
-- Title is rendered via the native custom.ui.window `title` segment API so it
-- sits *inside* the border line — identical to noice.nvim's visual style.
-- No buffer row is consumed for the title; the window body is pure content.
--
-- Highlights consumed (defined in colors.lua):
--   NvimCmdlineUiTitleIcon   — icon segment in border title (accent fg + tinted bg)
--   NvimCmdlineUiTitleText   — text segment in border title
--   NvimCmdlineUiNormal      — window body bg/fg
--   NvimCmdlineUiBorder      — border fg (glowing accent)
--   NvimCmdlineUiSel         — extmark highlight on selected row (select menu)
--   NvimCmdlineUiSelCursor   — winhighlight CursorLine redirect (select menu)
--   NvimCmdlineUiPrompt      — the "› " prefix on the input line
--   NvimCmdlineUiDim         — item index counter, footnote text

local M = {}

-- ---------------------------------------------------------------------------
-- Namespaces
-- ---------------------------------------------------------------------------
local NS_SEL = vim.api.nvim_create_namespace("nvim_cmdline_ui_sel")
local NS_DEC = vim.api.nvim_create_namespace("nvim_cmdline_ui_dec")

-- ---------------------------------------------------------------------------
-- Shared helpers
-- ---------------------------------------------------------------------------

---@param width  integer
---@param height integer
---@return integer row, integer col
local function center_pos(width, height)
  local row = math.floor((vim.o.lines - height) / 2) - 1
  local col = math.floor((vim.o.columns - width) / 2)
  return math.max(0, row), math.max(0, col)
end

---@param desired integer
---@return integer
local function clamp_width(desired)
  local max_w = math.floor(vim.o.columns * 0.68)
  local min_w = 40
  return math.max(min_w, math.min(max_w, desired))
end

---@return integer
local function make_buf()
  local buf = require("custom.ui.buffer").create_raw(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  return buf
end

---@param win integer?
local function close_win(win)
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
  end
end

---@param ag integer?
local function del_aug(ag)
  if ag then
    pcall(vim.api.nvim_del_augroup_by_id, ag)
  end
end

--- Build the two-segment border title used by custom.ui.window.
--- Produces:  ╭─  icon  label ─╮  (styled like noice.nvim)
---@param icon  string   e.g. " " or "󰒓 "
---@param label string   human-readable prompt text
---@return table  segment list accepted by custom.ui.window title
local function make_title(icon, label)
  local segments = {}
  if icon and icon ~= "" then
    table.insert(segments, { " " .. icon .. " ", "NvimCmdlineUiTitleIcon" })
  end
  table.insert(segments, { " " .. label .. " ", "NvimCmdlineUiTitleText" })
  return segments
end

--- Apply a virtual-text prompt decoration on the input line.
---@param buf     integer
---@param row     integer  0-indexed buffer row
local function apply_prompt_virt(buf, row)
  vim.api.nvim_buf_clear_namespace(buf, NS_DEC, 0, -1)
  -- Overlay on the leading space trick
  require("custom.ui.render").set_extmark(buf, NS_DEC, row, 0, {
    virt_text = { { "› ", "NvimCmdlineUiPrompt" } },
    virt_text_pos = "overlay",
    priority = 10,
  })
end

--- Apply selected-row highlight in the select menu.
---@param buf     integer
---@param buf_row integer  0-indexed
local function apply_sel_hl(buf, buf_row)
  local line_count = vim.api.nvim_buf_line_count(buf)
  vim.api.nvim_buf_clear_namespace(buf, NS_SEL, 0, -1)
  if buf_row >= 0 and buf_row < line_count then
    require("custom.ui.render").add_highlight(buf, NS_SEL, "NvimCmdlineUiSel", buf_row, 0, -1)
  end
end

-- ---------------------------------------------------------------------------
-- Extra highlight definitions (supplement colors.lua without touching it)
-- ---------------------------------------------------------------------------
local function ensure_ui_hls()
  -- Only define what colors.lua does not already provide.
  local defined = vim.api.nvim_get_hl(0, { name = "NvimCmdlineUiTitleIcon" })
  if defined and (defined.fg or defined.bg) then
    return
  end
  -- Fallback definitions so the module works standalone.
  local function hl(name, opts)
    vim.api.nvim_set_hl(0, name, opts)
  end
  hl("NvimCmdlineUiTitleIcon", { fg = 0x79c0ff, bg = 0x12243d, bold = true })
  hl("NvimCmdlineUiTitleText", { fg = 0xd0d7de, bg = 0x12243d })
  -- bg = NONE → transparent window body
  hl("NvimCmdlineUiNormal", { fg = 0xe6edf3 })
  hl("NvimCmdlineUiBorder", { fg = 0x84bdf7 })
  hl("NvimCmdlineUiSel", { fg = 0xe6edf3, bg = 0x213a58, bold = true })
  hl("NvimCmdlineUiSelCursor", { fg = 0xe6edf3, bg = 0x213a58, bold = true })
  hl("NvimCmdlineUiPrompt", { fg = 0x58a6ff, bold = true })
  hl("NvimCmdlineUiDim", { fg = 0x677189 })
end

-- ---------------------------------------------------------------------------
-- vim.ui.input
-- ---------------------------------------------------------------------------

---@param opts       table  { prompt?: string, default?: string, ... }
---@param on_confirm fun(input: string|nil)
function M.input(opts, on_confirm)
  ensure_ui_hls()
  opts = opts or {}

  local raw_prompt = opts.prompt or ""
  local default = type(opts.default) == "string" and opts.default or ""

  -- Normalise: strip trailing colon/space variants (supports full-width colons too)
  local prompt = tostring(raw_prompt):gsub("%s*[:：]%s*$", ""):gsub("%s+$", "")
  local title_label = #prompt > 0 and prompt or "Input"

  local inner_w =
    clamp_width(math.max(48, vim.api.nvim_strwidth(title_label) + 12, vim.api.nvim_strwidth(default) + 10))
  local height = 1
  local row, col = center_pos(inner_w + 2, height + 2) -- +2 for border

  local buf = make_buf()
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { default })

  local win = require("custom.ui.window").open_raw(buf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = inner_w,
    height = height,
    style = "minimal",
    border = "rounded",
    title = make_title("󰘥 ", title_label),
    title_pos = "center",
    zindex = 250,
    noautocmd = true,
  })

  vim.wo[win].winhighlight =
    "Normal:NvimCmdlineUiNormal,FloatBorder:NvimCmdlineUiBorder,NormalFloat:NvimCmdlineUiNormal"
  vim.wo[win].wrap = false
  vim.wo[win].cursorline = false
  vim.wo[win].scrolloff = 0

  -- Disable blink.cmp
  vim.bo[buf].complete = ""
  vim.b[buf].completion = false
  vim.b[buf].blink_cmp_enabled = false

  -- Inline "› " prompt decoration
  vim.api.nvim_buf_clear_namespace(buf, NS_DEC, 0, -1)
  require("custom.ui.render").set_extmark(buf, NS_DEC, 0, 0, {
    virt_text = { { " › ", "NvimCmdlineUiPrompt" } },
    virt_text_pos = "inline",
    right_gravity = false,
    priority = 10,
  })

  -- Place cursor at end of text
  pcall(vim.api.nvim_win_set_cursor, win, { 1, #default })

  local ag = vim.api.nvim_create_augroup("NvimCmdlineUiInput" .. buf, { clear = true })

  local function confirm()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, 1, false)
    local value = lines[1] or ""
    close_win(win)
    del_aug(ag)
    vim.schedule(function()
      on_confirm(value)
    end)
  end

  local function cancel()
    close_win(win)
    del_aug(ag)
    vim.schedule(function()
      on_confirm(nil)
    end)
  end

  local map_opts = { buffer = buf, noremap = true, silent = true, nowait = true }
  vim.keymap.set({ "i", "n" }, "<CR>", confirm, map_opts)
  vim.keymap.set({ "i", "n" }, "<Esc>", cancel, map_opts)
  vim.keymap.set({ "i", "n" }, "<C-c>", cancel, map_opts)

  vim.cmd("startinsert!")
end

-- ---------------------------------------------------------------------------
-- vim.ui.select
-- ---------------------------------------------------------------------------

---@param items     table
---@param opts      table  { prompt?: string, format_item?: fun(item):string }
---@param on_choice fun(item, idx)
function M.select(items, opts, on_choice)
  ensure_ui_hls()
  opts = opts or {}

  if not items or #items == 0 then
    on_choice(nil, nil)
    return
  end

  local raw_prompt = opts.prompt or ""
  local format_item = type(opts.format_item) == "function" and opts.format_item or tostring

  -- Normalise: strip trailing colon/space variants (supports full-width colons too)
  local prompt = tostring(raw_prompt):gsub("%s*[:：]%s*$", ""):gsub("%s+$", "")
  local title_label = #prompt > 0 and prompt or "Select"

  -- Build display lines (leading space for visual breathing room)
  local display = {}
  local max_label = vim.api.nvim_strwidth("  " .. title_label)
  for _, item in ipairs(items) do
    local label = tostring(format_item(item))
    local display_label = "  " .. label
    table.insert(display, display_label)
    max_label = math.max(max_label, vim.api.nvim_strwidth(display_label))
  end

  local n_items = #items
  local max_visible = math.min(n_items, math.floor(vim.o.lines * 0.55))
  local inner_w = clamp_width(math.max(40, max_label + 6))
  local height = max_visible -- no title row — it's in the border

  local row, col = center_pos(inner_w + 2, height + 2)

  local buf = make_buf()

  -- Pad lines for consistent background coverage
  local all_lines = {}
  for _, d in ipairs(display) do
    local width = vim.api.nvim_strwidth(d)
    table.insert(all_lines, d .. string.rep(" ", math.max(0, inner_w - width)))
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, all_lines)

  -- Add right-aligned index virtual text for each row
  for i = 1, n_items do
    local counter = string.format("%d/%d", i, n_items)
    require("custom.ui.render").set_extmark(buf, NS_DEC, i - 1, 0, {
      virt_text = { { counter .. " ", "NvimCmdlineUiDim" } },
      virt_text_pos = "right_align",
      priority = 5,
    })
  end

  vim.bo[buf].modifiable = false

  local win = require("custom.ui.window").open_raw(buf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = inner_w,
    height = height,
    style = "minimal",
    border = "rounded",
    title = make_title("", title_label),
    title_pos = "center",
    footer = { { "  <CR> confirm  <Esc> cancel  j/k navigate ", "NvimCmdlineUiDim" } },
    footer_pos = "left",
    zindex = 250,
    noautocmd = true,
  })

  vim.wo[win].winhighlight =
    "Normal:NvimCmdlineUiNormal,FloatBorder:NvimCmdlineUiBorder,NormalFloat:NvimCmdlineUiNormal,CursorLine:NvimCmdlineUiSelCursor"
  vim.wo[win].wrap = false
  vim.wo[win].cursorline = true
  vim.wo[win].scrolloff = 2

  local sel = 1

  local function move_to(idx)
    sel = math.max(1, math.min(n_items, idx))
    apply_sel_hl(buf, sel - 1) -- 0-indexed
    pcall(vim.api.nvim_win_set_cursor, win, { sel, 0 })
  end

  move_to(1)

  local ag = vim.api.nvim_create_augroup("NvimCmdlineUiSelect" .. buf, { clear = true })

  -- Sync sel state when cursor moves (e.g. mouse, <C-d>, etc.)
  vim.api.nvim_create_autocmd({ "CursorMoved" }, {
    buffer = buf,
    group = ag,
    callback = function()
      local cur = vim.api.nvim_win_get_cursor(win)
      local new_sel = cur[1]
      if new_sel >= 1 and new_sel <= n_items and new_sel ~= sel then
        sel = new_sel
        apply_sel_hl(buf, sel - 1)
      end
    end,
  })

  local function confirm()
    local chosen = items[sel]
    local chosen_idx = sel
    close_win(win)
    del_aug(ag)
    vim.schedule(function()
      on_choice(chosen, chosen_idx)
    end)
  end

  local function cancel()
    close_win(win)
    del_aug(ag)
    vim.schedule(function()
      on_choice(nil, nil)
    end)
  end

  local map_opts = { buffer = buf, noremap = true, silent = true, nowait = true }

  vim.keymap.set("n", "<CR>", confirm, map_opts)
  vim.keymap.set("n", "<Esc>", cancel, map_opts)
  vim.keymap.set("n", "q", cancel, map_opts)
  vim.keymap.set("n", "<C-c>", cancel, map_opts)
  vim.keymap.set("n", "j", function()
    move_to(sel + 1)
  end, map_opts)
  vim.keymap.set("n", "k", function()
    move_to(sel - 1)
  end, map_opts)
  vim.keymap.set("n", "<Down>", function()
    move_to(sel + 1)
  end, map_opts)
  vim.keymap.set("n", "<Up>", function()
    move_to(sel - 1)
  end, map_opts)
  vim.keymap.set("n", "G", function()
    move_to(n_items)
  end, map_opts)
  vim.keymap.set("n", "gg", function()
    move_to(1)
  end, map_opts)
  -- Quick numeric jump
  for n = 1, math.min(9, n_items) do
    vim.keymap.set("n", tostring(n), function()
      move_to(n)
    end, map_opts)
  end

  vim.cmd("stopinsert")
  pcall(vim.api.nvim_win_set_cursor, win, { 1, 0 })
end

-- ---------------------------------------------------------------------------
-- colors.lua supplement
-- Adds the two title-segment groups if colors.lua has not defined them.
-- Call this AFTER colors.setup_highlights() so it only fills gaps.
-- ---------------------------------------------------------------------------
function M.setup_highlights()
  -- These are the groups consumed exclusively by vim_ui.lua.
  -- If colors.lua already sets them the call below is a no-op (same values).
  local c = require("custom.cmdline.colors").get_palette()
  local function hl(name, o)
    vim.api.nvim_set_hl(0, name, o)
  end

  hl("NvimCmdlineUiTitleIcon", { fg = c.cyan, bg = c.tbg_cmd, bold = true })
  hl("NvimCmdlineUiTitleText", { fg = c.fg2, bg = c.tbg_cmd })
  -- bg intentionally omitted → transparent window body
  hl("NvimCmdlineUiNormal", { fg = c.fg2 })
  hl("NvimCmdlineUiBorder", { fg = c.border_glow })
  -- Selection
  hl("NvimCmdlineUiSel", { fg = c.fg, bg = c.sel_bg, bold = true })
  hl("NvimCmdlineUiSelCursor", { fg = c.fg, bg = c.sel_bg, bold = true })
  -- Inline prompt glyph
  hl("NvimCmdlineUiPrompt", { fg = c.cyan2, bold = true })
  -- Dim footnotes / counters
  hl("NvimCmdlineUiDim", { fg = c.dim })
end

-- ---------------------------------------------------------------------------
-- Install
-- ---------------------------------------------------------------------------

function M.setup()
  M.setup_highlights()
  vim.ui.input = M.input
  vim.ui.select = M.select
end

return M
