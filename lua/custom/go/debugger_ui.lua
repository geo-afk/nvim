-- debugger_ui.lua — compact Go debugger UI for Neovim 0.11+
--
-- Layout (right sidebar + thin output strip at bottom):
--
--  ┌───────────────────────────┬──────────────────────┐
--  │                           │ ▼ 󰫧 Variables       │
--  │   <editing area>          │   x        = 42      │
--  │                           │   msg      = "hello" │
--  │                           │ ─────────────────── │
--  │                           │ ▼ 󰆼 Call Stack  3   │
--  │                           │ ▶  1  main.Run       │
--  │                           │       main.go:42     │
--  │                           │ ─────────────────── │
--  │                           │ ▼ 󰝥 Breakpoints  2  │
--  │                           │ ● main.go:10         │
--  ├───────────────────────────┴──────────────────────┤
--  │ 󰆍 Output  ·  ⏸ stopped at main.go:42            │
--  │  > process started (pid 91823)                   │
--  └──────────────────────────────────────────────────┘
--
-- Sidebar keys:  <CR>=toggle collapse  <Tab>=next section  q=close

local M = {}

local output_parser = require("custom.go.debugger_output")

-- ─── namespaces ───────────────────────────────────────────────────────────────

local NS = vim.api.nvim_create_namespace("go_dbg_ui")
local NS_SRC = vim.api.nvim_create_namespace("go_dbg_src")

-- ─── signs ────────────────────────────────────────────────────────────────────

local SIGN_BP = "GoDbgBP"
local SIGN_BP_COND = "GoDbgBPCond"
local SIGN_BP_LOG = "GoDbgBPLog"
local SIGN_PC = "GoDbgPC"

-- ─── section definitions (render order) ──────────────────────────────────────

local SECTIONS = {
  { id = "variables", icon = "󰫧", title = "Variables" },
  { id = "stack", icon = "󰆼", title = "Call Stack" },
  { id = "breakpoints", icon = "󰝥", title = "Breakpoints" },
  { id = "watches", icon = "󰈈", title = "Watches" },
}

-- ─── state ────────────────────────────────────────────────────────────────────

local S = {
  open = false,
  wins = {}, -- { sidebar, output }
  bufs = {}, -- { sidebar, output }
  sections = {
    variables = { collapsed = false, items = {}, count = nil },
    stack = { collapsed = false, items = {}, count = nil },
    breakpoints = { collapsed = false, items = {}, count = nil },
    watches = { collapsed = false, items = {}, count = nil },
  },
  sec_rows = {}, -- { [1-based row] = sec_id }  for <CR> toggle
  output = {},
  max_output = 300,
  last_status = "",
  current = nil, -- { file, line }
  bp_signs = {}, -- { [bufnr] = { sign_id, ... } }
  sign_ctr = 3000,
  pending = {},
}

-- ─── highlight groups ─────────────────────────────────────────────────────────

local function setup_hl()
  local function def(name, opts)
    opts.default = true
    vim.api.nvim_set_hl(0, name, opts)
  end
  -- sidebar chrome
  def("GoDbgSectionHdr", { link = "Title", bold = true })
  def("GoDbgSectionIcon", { link = "DiagnosticInfo" })
  def("GoDbgSectionCnt", { link = "Comment" })
  def("GoDbgCollapse", { link = "NonText" })
  def("GoDbgDivider", { link = "WinSeparator" })
  -- variables
  def("GoDbgScopeName", { link = "Keyword", bold = true })
  def("GoDbgVarName", { link = "Identifier" })
  def("GoDbgVarType", { link = "Comment", italic = true })
  def("GoDbgVarVal", { link = "Number" })
  def("GoDbgVarStr", { link = "String" })
  def("GoDbgVarBool", { link = "Boolean" })
  def("GoDbgVarNil", { link = "Comment" })
  -- stack
  def("GoDbgFrameA", { link = "DiagnosticInfo", bold = true })
  def("GoDbgFrameI", { link = "Normal" })
  def("GoDbgFrameFile", { link = "Comment" })
  def("GoDbgFrameArrow", { link = "DiagnosticInfo" })
  -- breakpoints
  def("GoDbgBPFile", { link = "Normal" })
  def("GoDbgBPLnum", { link = "Number" })
  def("GoDbgBPCond", { link = "DiagnosticWarn" })
  -- output
  def("GoDbgOutEvent", { link = "DiagnosticInfo" })
  def("GoDbgOutLog", { link = "Normal" })
  def("GoDbgOutErr", { link = "DiagnosticError" })
  def("GoDbgOutWarn", { link = "DiagnosticWarn" })
  def("GoDbgOutProgram", { link = "String" })
  def("GoDbgOutProtocol", { link = "Comment" })
  def("GoDbgOutRaw", { link = "DiagnosticUnnecessary" })
  -- source
  def("GoDbgExecLine", { link = "CursorLine" })
  def("GoDbgExecVirt", {
    link = "DiagnosticVirtualTextInfo",
    italic = true,
  })
  -- signs
  vim.fn.sign_define(SIGN_BP, {
    text = "●",
    texthl = "DiagnosticError",
    numhl = "DiagnosticError",
  })
  vim.fn.sign_define(SIGN_BP_COND, {
    text = "◆",
    texthl = "DiagnosticWarn",
    numhl = "DiagnosticWarn",
  })
  vim.fn.sign_define(SIGN_BP_LOG, {
    text = "◇",
    texthl = "DiagnosticHint",
    numhl = "DiagnosticHint",
  })
  vim.fn.sign_define(
    SIGN_PC,
    { text = "▶", texthl = "DiagnosticInfo", linehl = "GoDbgExecLine", numhl = "DiagnosticInfo" }
  )
end

-- ─── path helpers ─────────────────────────────────────────────────────────────

local function norm(p)
  return vim.fn.fnamemodify(p, ":p"):gsub("\\", "/")
end
local function shrt(p)
  return vim.fn.fnamemodify(p, ":~:.")
end

-- ─── buffer helpers ───────────────────────────────────────────────────────────

local function get_buf(key)
  local b = S.bufs[key]
  if b and vim.api.nvim_buf_is_valid(b) then
    return b
  end
  b = vim.api.nvim_create_buf(false, true)
  vim.bo[b].bufhidden = "hide"
  vim.bo[b].buftype = "nofile"
  vim.bo[b].swapfile = false
  vim.bo[b].filetype = "godebug"
  pcall(vim.api.nvim_buf_set_name, b, "go-debug://" .. key)
  S.bufs[key] = b
  return b
end

local function write_buf(b, lines)
  if not vim.api.nvim_buf_is_valid(b) then
    return
  end
  vim.bo[b].modifiable = true
  vim.api.nvim_buf_set_lines(b, 0, -1, false, lines)
  vim.bo[b].modifiable = false
end

local function valid(key)
  local w = S.wins[key]
  return w and vim.api.nvim_win_is_valid(w)
end

local function sb_width()
  return math.max(32, math.floor(vim.o.columns * 0.24))
end

-- ─── debounce ─────────────────────────────────────────────────────────────────

local function defer(key, fn)
  if S.pending[key] then
    return
  end
  S.pending[key] = true
  vim.schedule(function()
    S.pending[key] = nil
    fn()
  end)
end

-- ─── item builders (convert data → display item lists) ───────────────────────
-- Each item: { text = string, hls = { {col0,col1,grp}, ... }, virt = string|nil }

local function val_hl(v)
  if v == "nil" or v == "<nil>" then
    return "GoDbgVarNil"
  end
  if v == "true" or v == "false" then
    return "GoDbgVarBool"
  end
  if v:sub(1, 1) == '"' or v:sub(1, 1) == "`" then
    return "GoDbgVarStr"
  end
  if v:match("^%-?%d") then
    return "GoDbgVarVal"
  end
  return "GoDbgVarName"
end

local function build_variable_items(scopes, vars_by_scope)
  local items = {}
  if not scopes or #scopes == 0 then
    return items, 0
  end
  local total = 0
  for _, scope in ipairs(scopes) do
    -- scope header (sub-section)
    local sh = " " .. (scope.name or "scope")
    table.insert(items, { text = sh, hls = { { col0 = 0, col1 = #sh, grp = "GoDbgScopeName" } } })
    local vars = vars_by_scope[scope.variablesReference] or {}
    for _, v in ipairs(vars) do
      total = total + 1
      local name = tostring(v.name or "?")
      local val = tostring(v.value or "")
      local typ = tostring(v.type or "")
      if #val > 42 then
        val = val:sub(1, 40) .. "…"
      end
      if #typ > 18 then
        typ = typ:sub(1, 16) .. "…"
      end
      -- layout:  "  name          = value"
      local pad = string.format("  %-14s", name)
      local text = pad .. "= " .. val
      table.insert(items, {
        text = text,
        hls = {
          { col0 = 0, col1 = #pad, grp = "GoDbgVarName" },
          { col0 = #pad + 2, col1 = #text, grp = val_hl(val) },
        },
        virt = typ ~= "" and (" " .. typ) or nil,
      })
    end
  end
  return items, total
end

local function build_stack_items(frames)
  local items = {}
  if not frames or #frames == 0 then
    return items, 0
  end
  for i, frame in ipairs(frames) do
    local active = (i == 1)
    local name = frame.name or ("frame " .. i)
    local src = (frame.source and frame.source.path) or ""
    local lnum = tostring(frame.line or "?")
    local arrow = active and "▶" or " "
    local row1 = string.format(" %s %2d  %s", arrow, i, name)
    table.insert(items, {
      text = row1,
      hls = {
        { col0 = 1, col1 = 2, grp = active and "GoDbgFrameArrow" or "GoDbgFrameI" },
        { col0 = 0, col1 = #row1, grp = active and "GoDbgFrameA" or "GoDbgFrameI" },
      },
    })
    if src ~= "" then
      local row2 = "       " .. shrt(src) .. ":" .. lnum
      table.insert(items, {
        text = row2,
        hls = { { col0 = 0, col1 = #row2, grp = "GoDbgFrameFile" } },
      })
    end
  end
  return items, #frames
end

local function build_bp_items(bps)
  local items = {}
  if not bps or #bps == 0 then
    return items, 0
  end
  for _, bp in ipairs(bps) do
    local icon = bp.condition and "◆" or "●"
    local ihl = bp.condition and "GoDbgBPCond" or "DiagnosticError"
    local f = shrt(bp.file)
    local lnum = tostring(bp.line)
    local text = string.format(" %s %s:%s", icon, f, lnum)
    local c_f = 3 + #icon
    local c_l = c_f + #f + 1
    table.insert(items, {
      text = text,
      hls = {
        { col0 = 1, col1 = 1 + #icon, grp = ihl },
        { col0 = c_f, col1 = c_f + #f, grp = "GoDbgBPFile" },
        { col0 = c_l, col1 = #text, grp = "GoDbgBPLnum" },
      },
    })
    if bp.condition then
      local ct = "     if " .. bp.condition
      table.insert(items, {
        text = ct,
        hls = { { col0 = 0, col1 = #ct, grp = "GoDbgBPCond" } },
      })
    end
  end
  return items, #bps
end

-- ─── sidebar render ───────────────────────────────────────────────────────────

local function render_sidebar()
  local b = S.bufs.sidebar
  if not b or not vim.api.nvim_buf_is_valid(b) then
    return
  end

  -- ── accumulate lines, highlights, divider rows, section-row map ──
  local lines = {}
  local hls = {} -- { row0, col0, col1, grp }
  local virts = {} -- { row0, text }  virtual-text type annotations
  local dividers = {} -- row0 after which to draw a divider virt_line
  local sec_rows = {} -- { [1-based row] = sec_id }

  local function hl(r, c0, c1, grp)
    if c1 > c0 then
      table.insert(hls, { r = r, c0 = c0, c1 = c1, grp = grp })
    end
  end

  for si, sec_def in ipairs(SECTIONS) do
    local sec = S.sections[sec_def.id]
    local row0 = #lines -- 0-based

    -- ── section header line ────────────────────────────────────────
    local tog = sec.collapsed and "▶" or "▼"
    local cnt_str = sec.count and (" " .. tostring(sec.count)) or ""
    local hdr = string.format(" %s %s %s%s", tog, sec_def.icon, sec_def.title, cnt_str)
    table.insert(lines, hdr)
    sec_rows[row0 + 1] = sec_def.id -- 1-based for cursor comparison

    -- colour header pieces
    hl(row0, 1, 2, "GoDbgCollapse")
    -- icon: starts at col 3, length = #icon (4 bytes for nerd font glyphs)
    hl(row0, 3, 3 + #sec_def.icon, "GoDbgSectionIcon")
    local t0 = 3 + #sec_def.icon + 1
    hl(row0, t0, t0 + #sec_def.title, "GoDbgSectionHdr")
    if #cnt_str > 0 then
      local cs = t0 + #sec_def.title
      hl(row0, cs, cs + #cnt_str, "GoDbgSectionCnt")
    end

    -- ── section body ──────────────────────────────────────────────
    if not sec.collapsed then
      for _, item in ipairs(sec.items) do
        local r = #lines
        table.insert(lines, item.text)
        for _, h in ipairs(item.hls or {}) do
          hl(r, h.col0, h.col1, h.grp)
        end
        if item.virt then
          table.insert(virts, { r = r, text = item.virt })
        end
      end
    end

    -- ── divider between sections (not after last) ─────────────────
    if si < #SECTIONS then
      table.insert(dividers, #lines - 1) -- last content row0
    end
  end

  -- write buffer
  write_buf(b, lines)

  -- clear + apply extmarks
  vim.api.nvim_buf_clear_namespace(b, NS, 0, -1)

  for _, h in ipairs(hls) do
    pcall(vim.api.nvim_buf_set_extmark, b, NS, h.r, h.c0, {
      end_col = h.c1,
      hl_group = h.grp,
      priority = 10,
    })
  end

  for _, v in ipairs(virts) do
    pcall(vim.api.nvim_buf_set_extmark, b, NS, v.r, 0, {
      virt_text = { { v.text, "GoDbgVarType" } },
      virt_text_pos = "eol",
      priority = 5,
    })
  end

  local dw = sb_width()
  for _, dr in ipairs(dividers) do
    pcall(vim.api.nvim_buf_set_extmark, b, NS, dr, 0, {
      virt_lines = { { { string.rep("─", dw), "GoDbgDivider" } } },
      virt_lines_above = false,
    })
  end

  -- highlight header rows with CursorLine-ish bg so they stand out
  for row1, _ in pairs(sec_rows) do
    pcall(vim.api.nvim_buf_set_extmark, b, NS, row1 - 1, 0, {
      line_hl_group = "StatusLineNC",
      priority = 1,
    })
  end

  S.sec_rows = sec_rows
end

-- ─── public render functions ──────────────────────────────────────────────────

function M.render_variables(scopes, vars_by_scope)
  defer("sidebar", function()
    local items, count = build_variable_items(scopes or {}, vars_by_scope or {})
    S.sections.variables.items = items
    S.sections.variables.count = count > 0 and count or nil
    render_sidebar()
  end)
end

function M.render_stack(frames)
  defer("sidebar", function()
    local items, count = build_stack_items(frames or {})
    S.sections.stack.items = items
    S.sections.stack.count = count > 0 and count or nil
    render_sidebar()
  end)
end

function M.render_breakpoints(bps)
  defer("sidebar", function()
    local items, count = build_bp_items(bps or {})
    S.sections.breakpoints.items = items
    S.sections.breakpoints.count = count > 0 and count or nil
    render_sidebar()
  end)
end

-- ─── output panel ─────────────────────────────────────────────────────────────

local function output_line(item)
  if type(item) == "string" then
    return item, "GoDbgOutLog"
  end

  local kind = item.kind or "log"
  local text = item.text or ""
  if kind == "error" then
    return "! " .. text, "GoDbgOutErr"
  end
  if kind == "warn" then
    return "? " .. text, "GoDbgOutWarn"
  end
  if kind == "event" then
    return text, "GoDbgOutEvent"
  end
  if kind == "program" then
    return "> " .. text, "GoDbgOutProgram"
  end
  if kind == "protocol" then
    return ". " .. text, "GoDbgOutProtocol"
  end
  if kind == "raw" then
    return "? raw: " .. text, "GoDbgOutRaw"
  end
  if kind == "detail" then
    return "  " .. text, "GoDbgOutProtocol"
  end
  return ". " .. text, "GoDbgOutLog"
end

function M.append_output(raw)
  if raw == nil or raw == "" then
    return
  end
  for _, item in ipairs(output_parser.parse(raw)) do
    table.insert(S.output, item)
    if item.kind ~= "detail" and item.kind ~= "protocol" then
      S.last_status = item.text
    end
  end
  while #S.output > S.max_output do
    table.remove(S.output, 1)
  end

  defer("output", function()
    local b = S.bufs.output
    if not b or not vim.api.nvim_buf_is_valid(b) then
      return
    end

    local view_start = math.max(1, #S.output - 180)
    local lines = {}
    local groups = {}
    for i = view_start, #S.output do
      local text, grp = output_line(S.output[i])
      table.insert(lines, "  " .. text)
      table.insert(groups, grp)
    end
    if #lines == 0 then
      lines = { "  (no output)" }
      groups = { "GoDbgOutLog" }
    end

    write_buf(b, lines)
    vim.api.nvim_buf_clear_namespace(b, NS, 0, -1)

    for i, line in ipairs(lines) do
      pcall(vim.api.nvim_buf_set_extmark, b, NS, i - 1, 0, {
        end_col = #line,
        hl_group = groups[i] or "GoDbgOutLog",
        priority = 5,
      })
    end

    if valid("output") then
      pcall(vim.api.nvim_win_set_cursor, S.wins.output, { #lines, 0 })
      -- update winbar
      M._set_output_winbar()
    end
  end)
end

function M._set_output_winbar()
  if not valid("output") then
    return
  end
  local last = S.last_status
  if #last > 55 then
    last = last:sub(1, 52) .. "…"
  end
  local wb = " 󰆍 Output  ·  " .. last
  pcall(function()
    vim.wo[S.wins.output].winbar = wb
  end)
end

-- ─── sidebar keymaps ──────────────────────────────────────────────────────────

local function toggle_section_at_cursor()
  local r = vim.api.nvim_win_get_cursor(0)[1]
  local id = S.sec_rows[r]
  if id then
    S.sections[id].collapsed = not S.sections[id].collapsed
    render_sidebar()
  end
end

local function jump_section(dir)
  local cur = vim.api.nvim_win_get_cursor(0)[1]
  local rows = vim.tbl_keys(S.sec_rows)
  table.sort(rows)
  if #rows == 0 then
    return
  end
  if dir > 0 then
    for _, r in ipairs(rows) do
      if r > cur then
        pcall(vim.api.nvim_win_set_cursor, 0, { r, 0 })
        return
      end
    end
    pcall(vim.api.nvim_win_set_cursor, 0, { rows[1], 0 })
  else
    for i = #rows, 1, -1 do
      if rows[i] < cur then
        pcall(vim.api.nvim_win_set_cursor, 0, { rows[i], 0 })
        return
      end
    end
    pcall(vim.api.nvim_win_set_cursor, 0, { rows[#rows], 0 })
  end
end

local function bind_sidebar(b)
  local function km(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { buffer = b, silent = true, nowait = true, desc = desc })
  end
  km("q", M.close, "close debugger UI")
  km("<Esc>", M.close, "close debugger UI")
  km("<CR>", toggle_section_at_cursor, "toggle section")
  km("<Tab>", function()
    jump_section(1)
  end, "next section")
  km("<S-Tab>", function()
    jump_section(-1)
  end, "prev section")
  km("R", M.refresh, "refresh layout")
end

local function bind_output(b)
  local function km(lhs, rhs)
    vim.keymap.set("n", lhs, rhs, { buffer = b, silent = true, nowait = true })
  end
  km("q", M.close)
  km("<Esc>", M.close)
  km("G", function()
    if valid("output") then
      local lc = vim.api.nvim_buf_line_count(S.bufs.output)
      pcall(vim.api.nvim_win_set_cursor, S.wins.output, { lc, 0 })
    end
  end)
end

-- ─── layout open / close ──────────────────────────────────────────────────────
--
-- Split order matters for geometry:
--   1.  botright Hsplit   → full-width bottom strip (output)
--   2.  return to editing window
--   3.  botright Wvsplit  → right sidebar only within the upper area

function M.open()
  if S.open and valid("sidebar") then
    return
  end

  setup_hl()
  output_parser.reset()

  local origin = vim.api.nvim_get_current_win()
  local sb = get_buf("sidebar")
  local ob = get_buf("output")
  bind_sidebar(sb)
  bind_output(ob)

  -- 1. full-width bottom output strip
  vim.cmd("botright 8split")
  S.wins.output = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(S.wins.output, ob)
  -- window options
  for k, v in pairs({
    number = false,
    relativenumber = false,
    signcolumn = "no",
    wrap = false,
    cursorline = false,
    winfixheight = true,
    winfixwidth = false,
    foldcolumn = "0",
    spell = false,
  }) do
    pcall(function()
      vim.wo[S.wins.output][k] = v
    end)
  end
  vim.wo[S.wins.output].statusline = " 󰆍 Output"

  -- 2. return to editing area
  vim.api.nvim_set_current_win(origin)

  -- 3. right sidebar
  local sw = sb_width()
  vim.cmd("botright " .. sw .. "vsplit")
  S.wins.sidebar = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(S.wins.sidebar, sb)
  for k, v in pairs({
    number = false,
    relativenumber = false,
    signcolumn = "no",
    wrap = false,
    cursorline = true,
    winfixwidth = true,
    winfixheight = false,
    foldcolumn = "0",
    spell = false,
  }) do
    pcall(function()
      vim.wo[S.wins.sidebar][k] = v
    end)
  end
  vim.wo[S.wins.sidebar].statusline = " 󰃡 Debug"

  S.open = true

  -- return focus to editor
  if vim.api.nvim_win_is_valid(origin) then
    vim.api.nvim_set_current_win(origin)
  end

  render_sidebar()
  M.append_output("debug UI ready")
end

function M.close()
  for key, win in pairs(S.wins) do
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    S.wins[key] = nil
  end
  S.open = false
end

function M.toggle()
  if S.open and valid("sidebar") then
    M.close()
  else
    M.open()
  end
end

function M.is_open()
  return S.open and valid("sidebar")
end

function M.refresh()
  if not S.open then
    return
  end
  if valid("sidebar") then
    pcall(vim.api.nvim_win_set_width, S.wins.sidebar, sb_width())
    render_sidebar()
  end
  M._set_output_winbar()
end

-- ─── source-file decoration ───────────────────────────────────────────────────

local function buf_for_file(file)
  file = norm(file)
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(b) and norm(vim.api.nvim_buf_get_name(b)) == file then
      return b
    end
  end
  return vim.fn.bufadd(file)
end

function M.clear_execution_line()
  if not S.current then
    return
  end
  local b = buf_for_file(S.current.file)
  if vim.api.nvim_buf_is_valid(b) then
    vim.api.nvim_buf_clear_namespace(b, NS_SRC, 0, -1)
    vim.fn.sign_unplace("go_dbg_pc", { buffer = b })
  end
  S.current = nil
end

function M.show_execution_line(file, line, reason)
  M.clear_execution_line()
  local b = buf_for_file(file)
  S.current = { file = norm(file), line = line }

  vim.fn.sign_place(1, "go_dbg_pc", SIGN_PC, b, { lnum = line, priority = 90 })
  vim.api.nvim_buf_set_extmark(b, NS_SRC, line - 1, 0, {
    virt_text = { { "  ⏸ " .. (reason or "stopped"), "GoDbgExecVirt" } },
    virt_text_pos = "eol",
    hl_mode = "combine",
    priority = 100,
  })

  -- update output winbar
  S.last_status = string.format("⏸ %s  %s:%d", reason or "stopped", shrt(file), line)
  M._set_output_winbar()

  -- navigate editor window to stopped location
  local target = vim.fn.bufwinid(b)
  if target == -1 then
    vim.cmd("edit " .. vim.fn.fnameescape(file))
    target = vim.api.nvim_get_current_win()
  end
  if vim.api.nvim_win_is_valid(target) then
    local is_panel = (target == S.wins.sidebar or target == S.wins.output)
    if not is_panel then
      vim.api.nvim_win_set_cursor(target, { line, 0 })
      local focus = vim.api.nvim_get_current_win()
      if focus ~= S.wins.sidebar and focus ~= S.wins.output then
        vim.api.nvim_set_current_win(target)
      end
    end
  end
end

-- ─── breakpoint signs ─────────────────────────────────────────────────────────

function M.render_breakpoint_signs(bps)
  -- clear old signs
  for b, ids in pairs(S.bp_signs) do
    if vim.api.nvim_buf_is_valid(b) then
      for _, id in ipairs(ids) do
        vim.fn.sign_unplace("go_dbg_bp", { buffer = b, id = id })
      end
    end
  end
  S.bp_signs = {}

  for _, bp in ipairs(bps or {}) do
    local b = buf_for_file(bp.file)
    local sign = bp.logMessage and SIGN_BP_LOG or (bp.condition and SIGN_BP_COND) or SIGN_BP
    S.sign_ctr = S.sign_ctr + 1
    vim.fn.sign_place(S.sign_ctr, "go_dbg_bp", sign, b, { lnum = bp.line, priority = 50 })
    S.bp_signs[b] = S.bp_signs[b] or {}
    table.insert(S.bp_signs[b], S.sign_ctr)
  end
end

function M.render_watches(watch_list)
  watch_list = watch_list or {}
  defer("sidebar", function()
    local items, count = {}, 0
    if #watch_list == 0 then
      table.insert(items, {
        text = "  no watches",
        hls = { { col0 = 2, col1 = 10, grp = "GoDbgVarNil" } },
      })
    else
      for _, w in ipairs(watch_list) do
        count = count + 1
        local val = tostring(w.value or "…")
        if #val > 40 then
          val = val:sub(1, 38) .. "…"
        end
        local pad = string.format("  %-18s", w.expr)
        local text = pad .. "= " .. val
        local grp = w.error and "GoDbgOutErr" or "GoDbgVarVal"
        table.insert(items, {
          text = text,
          hls = {
            { col0 = 0, col1 = #pad, grp = "GoDbgVarName" },
            { col0 = #pad + 2, col1 = #text, grp = grp },
          },
        })
      end
    end
    S.sections.watches.items = items
    S.sections.watches.count = count > 0 and count or nil
    render_sidebar()
  end)
end

function M.setup()
  setup_hl()
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("GoDbgHL", { clear = true }),
    callback = setup_hl,
  })
  vim.api.nvim_create_autocmd("VimResized", {
    group = vim.api.nvim_create_augroup("GoDbgResize", { clear = true }),
    callback = function()
      if S.open then
        M.refresh()
      end
    end,
  })
end

return M
