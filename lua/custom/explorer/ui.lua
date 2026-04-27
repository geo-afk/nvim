-- custom/explorer/ui.lua
-- Floating popups: prompt, confirm, file info, help.

local S = require("custom.explorer.state")
local cfg = require("custom.explorer.config")
local nvim_utils = require("utils.nvim")

local api = vim.api
local fn = vim.fn
local M = {}

-- ── Helpers ───────────────────────────────────────────────────────────────

local function paste_from_clipboard()
  local text = fn.getreg("+")
  if text == nil or text == "" then
    text = fn.getreg("*")
  end
  if text == nil or text == "" then
    return
  end
  api.nvim_paste(text, true, -1)
end

local function set_buf_opt(buf, name, value)
  api.nvim_set_option_value(name, value, { buf = buf })
end

local function set_win_opt(win, name, value)
  api.nvim_set_option_value(name, value, { win = win })
end

local function def(name, opts)
  pcall(api.nvim_set_hl, 0, name, opts)
end

local function get_hl(name)
  local ok, hl = pcall(api.nvim_get_hl, 0, { name = name, link = false })
  return ok and hl or {}
end

local function clamp(v, lo, hi)
  return math.max(lo, math.min(hi, v))
end

local function editor_size()
  local ui = api.nvim_list_uis()[1]
  if ui then
    return ui.width, ui.height
  end
  return vim.o.columns, vim.o.lines
end

-- ── Popup highlight groups ────────────────────────────────────────────────

function M.ensure_hl()
  local ok, ex = pcall(api.nvim_get_hl, 0, { name = "ExplorerPopupNormal", link = false })
  if ok and ex and next(ex) then
    return
  end

  local normal = get_hl("ExplorerNormal")
  local float_ = get_hl("NormalFloat")
  local border_ = get_hl("FloatBorder")
  local title_ = get_hl("FloatTitle")
  local comment = get_hl("Comment")
  local warn_ = get_hl("DiagnosticWarn")
  local string_ = get_hl("String")

  local bg = float_.bg or normal.bg or 0x1e1e2e
  local fg = float_.fg or normal.fg or 0xcdd6f4
  local muted = comment.fg or 0x6c7086
  local accent = title_.fg or string_.fg or fg
  local warn_fg = warn_.fg or 0xf9e2af
  local border_fg = border_.fg or accent

  def("ExplorerPopupNormal", { bg = bg, fg = fg })
  def("ExplorerPopupBorder", { bg = bg, fg = border_fg })
  def("ExplorerPopupTitle", { bg = bg, fg = accent, bold = true })
  def("ExplorerPopupFooter", { bg = bg, fg = muted, italic = true })
  def("ExplorerPopupPrompt", { bg = bg, fg = muted })
  def("ExplorerPopupValue", { bg = bg, fg = fg, bold = true })
  def("ExplorerPopupDangerBorder", { bg = bg, fg = warn_fg })
  def("ExplorerPopupDangerTitle", { bg = bg, fg = warn_fg, bold = true })
  def("ExplorerPopupSectionHead", { bg = bg, fg = accent, bold = true })
  def("ExplorerPopupKey", { bg = bg, fg = fg, bold = true })
  def("ExplorerPopupDesc", { bg = bg, fg = muted })
end

-- ── Close helper ─────────────────────────────────────────────────────────

local function close_float(win, buf)
  if win and api.nvim_win_is_valid(win) then
    pcall(api.nvim_win_close, win, true)
  elseif buf and api.nvim_buf_is_valid(buf) then
    pcall(api.nvim_buf_delete, buf, { force = true })
  end
end

-- ── Prompt float ──────────────────────────────────────────────────────────

local function prompt_float(opts)
  M.ensure_hl()

  opts = opts or {}
  local default = opts.default or ""
  local prompt = opts.prompt or ""
  local title = opts.title or " Input "
  local footer = opts.footer or " <Enter> confirm   <Esc> cancel "
  local border_hl = opts.danger and "ExplorerPopupDangerBorder" or "ExplorerPopupBorder"
  local title_hl = opts.danger and "ExplorerPopupDangerTitle" or "ExplorerPopupTitle"

  local editor_w, editor_h = editor_size()
  local width = clamp(
    math.max(
      32,
      fn.strdisplaywidth(prompt) + fn.strdisplaywidth(default) + 6,
      fn.strdisplaywidth(footer) + 4,
      fn.strdisplaywidth(title) + 6
    ),
    32,
    editor_w - 8
  )

  local buf = api.nvim_create_buf(false, true)
  set_buf_opt(buf, "buftype", "prompt")
  set_buf_opt(buf, "bufhidden", "wipe")
  set_buf_opt(buf, "swapfile", false)
  set_buf_opt(buf, "modifiable", true)
  set_buf_opt(buf, "filetype", "explorer_prompt")
  fn.prompt_setprompt(buf, prompt)

  local win = api.nvim_open_win(buf, true, {
    relative = "editor",
    style = "minimal",
    border = "rounded",
    title = title,
    title_pos = "center",
    footer = footer,
    footer_pos = "center",
    width = width,
    height = 1,
    row = math.max(1, math.floor((editor_h - 3) / 2)),
    col = math.max(0, math.floor((editor_w - width) / 2)),
    zindex = 250,
  })

  vim.wo[win].winhl = table.concat({
    "Normal:ExplorerPopupNormal",
    "FloatBorder:" .. border_hl,
    "FloatTitle:" .. title_hl,
    "FloatFooter:ExplorerPopupFooter",
  }, ",")
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].wrap = false
  pcall(set_win_opt, win, "statuscolumn", "")
  pcall(set_win_opt, win, "foldcolumn", "0")
  set_win_opt(win, "winblend", 6)

  local closed = false
  local function close()
    if closed then
      return
    end
    closed = true
    close_float(win, buf)
  end

  fn.prompt_setcallback(buf, function(text)
    close()
    vim.schedule(function()
      opts.on_submit(text)
    end)
  end)

  vim.keymap.set({ "i", "n" }, "<Esc>", close, { buffer = buf, silent = true, nowait = true })
  vim.keymap.set({ "i", "n" }, "<C-c>", close, { buffer = buf, silent = true, nowait = true })
  vim.keymap.set("i", "<C-v>", paste_from_clipboard, { buffer = buf, silent = true })
  vim.keymap.set("i", "<S-Insert>", paste_from_clipboard, { buffer = buf, silent = true })

  vim.schedule(function()
    if not api.nvim_win_is_valid(win) then
      return
    end
    vim.cmd("startinsert!")
    if default ~= "" then
      local keys = api.nvim_replace_termcodes(default, true, false, true)
      api.nvim_feedkeys(keys, "i", false)
    end
  end)
end

-- ── Public prompt / confirm ───────────────────────────────────────────────

function M.input(opts, on_submit)
  opts = vim.tbl_extend("keep", opts or {}, { on_submit = on_submit })
  prompt_float(opts)
end

function M.confirm(opts, on_confirm)
  opts = opts or {}
  prompt_float({
    title = opts.title or " Confirm ",
    prompt = (opts.prompt or "Confirm?") .. " (y/N): ",
    footer = opts.footer or " y confirm   <Esc> cancel ",
    danger = opts.danger,
    on_submit = function(text)
      on_confirm(text and text:lower() == "y")
    end,
  })
end

-- ── Path input ────────────────────────────────────────────────────────────

local function rel_to_root(root, path)
  if not root or root == "" or not path or path == "" then
    return path
  end
  if path == root then
    return ""
  end
  local prefix = root .. "/"
  if vim.startswith(path, prefix) then
    return path:sub(#prefix + 1)
  end
  return path
end

function M.rooted_path_input(opts, on_submit)
  opts = opts or {}
  local root = opts.root or ""
  local default = rel_to_root(root, opts.default or "")
  local root_label = " root: " .. fn.fnamemodify(root, ":~") .. " "
  local footer = opts.footer and (opts.footer .. "   " .. root_label) or root_label

  M.input({
    title = opts.title,
    prompt = opts.prompt or "Path: ",
    default = default,
    footer = footer,
  }, function(text)
    if not text or text == "" then
      on_submit(text)
      return
    end
    local normalized = text:gsub("\\", "/")
    if normalized:match("^%a:[/]") or vim.startswith(normalized, "/") then
      on_submit(normalized)
      return
    end
    on_submit(root .. "/" .. normalized)
  end)
end

-- ── Text popup (read-only floating window) ────────────────────────────────

local function open_text_popup(opts)
  M.ensure_hl()

  local lines = vim.deepcopy(opts.lines or {})
  local editor_w, editor_h = editor_size()

  local width = opts.width
  if not width then
    local max_w = 0
    for _, line in ipairs(lines) do
      max_w = math.max(max_w, fn.strdisplaywidth(line))
    end
    width = clamp(max_w + 4, 44, editor_w - 8)
  end
  local height = clamp(#lines, 1, editor_h - 6)

  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  set_buf_opt(buf, "bufhidden", "wipe")
  set_buf_opt(buf, "modifiable", false)
  set_buf_opt(buf, "filetype", opts.filetype or "explorer_popup")

  local win = api.nvim_open_win(buf, true, {
    relative = "editor",
    style = "minimal",
    border = "rounded",
    title = opts.title,
    title_pos = "center",
    footer = opts.footer,
    footer_pos = "center",
    width = width,
    height = height,
    row = math.max(1, math.floor((editor_h - height) / 2)),
    col = math.max(0, math.floor((editor_w - width) / 2)),
    zindex = 240,
  })

  vim.wo[win].winhl = table.concat({
    "Normal:ExplorerPopupNormal",
    "FloatBorder:" .. (opts.border_hl or "ExplorerPopupBorder"),
    "FloatTitle:" .. (opts.title_hl or "ExplorerPopupTitle"),
    "FloatFooter:ExplorerPopupFooter",
  }, ",")
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].cursorline = false
  set_win_opt(win, "winblend", 4)
  set_win_opt(win, "wrap", false)
  pcall(set_win_opt, win, "statuscolumn", "")
  pcall(set_win_opt, win, "foldcolumn", "0")

  local ns = api.nvim_create_namespace(opts.ns or ("explorer_popup_" .. (opts.filetype or "popup")))
  if opts.highlights then
    for _, hl in ipairs(opts.highlights) do
      local extmark = {
        hl_group = hl.group,
        hl_eol = hl.hl_eol,
        priority = 20,
      }
      if hl.col_end and hl.col_end >= 0 then
        extmark.end_col = hl.col_end
      end
      pcall(api.nvim_buf_set_extmark, buf, ns, hl.row, hl.col_start, extmark)
    end
  end

  nvim_utils.bind_close_keys(buf, win, opts.close_keys or { "q", "<Esc>", "<CR>" }, { silent = true })
  return buf, win
end

-- ── File info popup ───────────────────────────────────────────────────────

function M.file_info(item)
  local uv = vim.uv
  local stat = uv.fs_stat(item.path)
  local ls = uv.fs_lstat(item.path)
  if not stat then
    vim.notify("[explorer] stat failed: " .. item.path, vim.log.levels.WARN)
    return
  end

  local function fmt_size(n)
    if n < 1024 then
      return n .. " B"
    elseif n < 1024 ^ 2 then
      return ("%.1f KiB"):format(n / 1024)
    elseif n < 1024 ^ 3 then
      return ("%.1f MiB"):format(n / 1024 ^ 2)
    else
      return ("%.1f GiB"):format(n / 1024 ^ 3)
    end
  end

  local function fmt_time(s)
    return s and os.date("%Y-%m-%d  %H:%M:%S", s) or "—"
  end

  local function fmt_perm(mode)
    if not mode then
      return "—"
    end
    local bits = { "r", "w", "x", "r", "w", "x", "r", "w", "x" }
    local out = {}
    for i = 8, 0, -1 do
      out[#out + 1] = bit.band(mode, 2 ^ i) ~= 0 and bits[9 - i] or "-"
    end
    return ("%o  (%s)"):format(bit.band(mode, 0x1ff), table.concat(out))
  end

  -- ── Rows: label (fixed 14 chars) + value ─────────────────────────────
  local LABEL_W = 14
  local function row(label, value)
    return (" %-" .. (LABEL_W - 1) .. "s %s"):format(label, value)
  end

  local is_link = ls and ls.type == "link"

  local lines = {
    row("Path", fn.fnamemodify(item.path, ":~")),
    row("Type", stat.type .. (is_link and "  (symlink)" or "")),
    row("Size", item.is_dir and "—" or fmt_size(stat.size)),
    row("Modified", fmt_time(stat.mtime and stat.mtime.sec)),
    row("Created", fmt_time(stat.birthtime and stat.birthtime.sec)),
    row("Accessed", fmt_time(stat.atime and stat.atime.sec)),
  }

  if fn.has("win32") == 0 then
    lines[#lines + 1] = row("Permissions", fmt_perm(stat.mode))
    lines[#lines + 1] = row("Owner UID", tostring(stat.uid))
    lines[#lines + 1] = row("Group GID", tostring(stat.gid))
    lines[#lines + 1] = row("Hard links", tostring(stat.nlink))
  end

  if is_link then
    lines[#lines + 1] = row("Target", uv.fs_readlink(item.path) or "?")
  end

  local ch = S.git[item.path]
  if ch then
    local labels = {
      M = "Modified",
      A = "Added (staged)",
      D = "Deleted",
      R = "Renamed",
      ["?"] = "Untracked",
      U = "Conflict",
      I = "Ignored",
    }
    lines[#lines + 1] = row("Git", labels[ch] or ch)
  end

  -- Highlight every label column in muted colour
  local highlights = {}
  for r_idx = 0, #lines - 1 do
    highlights[#highlights + 1] = {
      row = r_idx,
      col_start = 0,
      col_end = LABEL_W,
      group = "ExplorerPopupPrompt",
    }
  end

  open_text_popup({
    title = "  " .. fn.fnamemodify(item.path, ":t") .. " ",
    footer = "  q / <Esc>  close ",
    filetype = "explorer_info",
    lines = lines,
    highlights = highlights,
    close_keys = { "q", "<Esc>", "<CR>" },
  })
end

-- ── Help popup ────────────────────────────────────────────────────────────

function M.help()
  local km = cfg.get().keymaps

  local function key(k)
    return type(k) == "table" and table.concat(k, " / ") or (k or "—")
  end

  -- Sections: { title, { { key, description }, … } }
  local sections = {
    {
      "  Navigation",
      {
        { key(km.open), "open file or toggle directory" },
        { key(km.close_dir), "collapse dir / jump to parent" },
        { key(km.go_up), "move root to parent directory" },
        { key(km.expand_all), "expand one level of directories" },
        { key(km.collapse_all), "collapse all open directories" },
      },
    },
    {
      "  Open In…",
      {
        { key(km.vsplit), "open in a vertical split" },
        { key(km.split), "open in a horizontal split" },
        { key(km.tab), "open in a new tab" },
      },
    },
    {
      "  File Operations",
      {
        { key(km.add), "create file or directory" },
        { key(km.delete), "delete item(s)" },
        { key(km.rename), "rename / move item" },
        { key(km.copy), "copy item(s)" },
        { key(km.move), "move item(s) to chosen directory" },
      },
    },
    {
      "  Search & Marks",
      {
        { key(km.search), "open the inline file filter" },
        { key(km.projects), "open the project picker" },
        { "<CR>  (in filter)", "keep current filter" },
        { "<Esc> (in filter)", "clear current filter" },
        { key(km.mark), "toggle file mark" },
      },
    },
    {
      "  Git",
      {
        { key(km.git_stage), "stage item or marked files" },
        { key(km.git_restore), "restore item or marked files" },
      },
    },
    {
      "  Misc",
      {
        { key(km.copy_path), "copy path variant to clipboard" },
        { key(km.file_info), "show file metadata" },
        { key(km.toggle_hidden), "toggle hidden files" },
        { key(km.refresh), "refresh tree and git status" },
        { key(km.help), "show this help" },
        { key(km.quit), "close the explorer" },
      },
    },
  }

  local KEY_W = 18 -- fixed column width for keys
  local lines = {}
  local hls = {}

  for _, section in ipairs(sections) do
    -- Section heading row
    local head_row = #lines
    lines[#lines + 1] = section[1]
    hls[#hls + 1] = {
      row = head_row,
      col_start = 0,
      col_end = -1,
      group = "ExplorerPopupSectionHead",
      hl_eol = true,
    }

    for _, entry in ipairs(section[2]) do
      local text = ("  %-" .. KEY_W .. "s  %s"):format(entry[1], entry[2])
      local line_row = #lines
      lines[#lines + 1] = text
      -- Key in bold
      hls[#hls + 1] = {
        row = line_row,
        col_start = 2,
        col_end = 2 + KEY_W,
        group = "ExplorerPopupKey",
      }
      -- Description in muted
      hls[#hls + 1] = {
        row = line_row,
        col_start = 2 + KEY_W + 2,
        col_end = -1,
        group = "ExplorerPopupDesc",
      }
    end

    -- Blank separator between sections
    lines[#lines + 1] = ""
  end

  -- Strip trailing blank
  if lines[#lines] == "" then
    lines[#lines] = nil
  end

  open_text_popup({
    title = "  Explorer Help ",
    footer = "  q / <Esc>  close ",
    filetype = "explorer_help",
    width = 68,
    lines = lines,
    highlights = hls,
    close_keys = { "q", "?", "<Esc>", "<CR>" },
  })
end

return M
