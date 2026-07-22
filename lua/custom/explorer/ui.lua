local S = require("custom.explorer.state")
local cfg = require("custom.explorer.config")
local nvim_utils = require("utils.nvim")

local api = vim.api
local fn = vim.fn

local M = {}

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

local function set_buf_option(buf, name, value)
  api.nvim_set_option_value(name, value, { buf = buf })
end

local function set_win_option(win, name, value)
  api.nvim_set_option_value(name, value, { win = win })
end

local function define(name, opts)
  pcall(api.nvim_set_hl, 0, name, opts)
end

local function get_hl(name)
  local ok, hl = pcall(api.nvim_get_hl, 0, { name = name, link = false })
  return ok and hl or {}
end

local function clamp(value, min_value, max_value)
  return math.max(min_value, math.min(max_value, value))
end

local function editor_size()
  local ui = api.nvim_list_uis()[1]
  if ui then
    return ui.width, ui.height
  end
  return vim.o.columns, vim.o.lines
end

function M.ensure_hl()
  local ok, ex = pcall(api.nvim_get_hl, 0, { name = "ExplorerPopupNormal", link = false })
  if ok and ex and next(ex) then
    return
  end

  local normal = get_hl("ExplorerNormal")
  local float = get_hl("NormalFloat")
  local border = get_hl("FloatBorder")
  local title = get_hl("FloatTitle")
  local comment = get_hl("Comment")
  local warn = get_hl("DiagnosticWarn")
  local string_hl = get_hl("String")

  local bg = float.bg or normal.bg or 0x1e1e2e
  local fg = float.fg or normal.fg or 0xcdd6f4
  local muted = comment.fg or 0x6c7086
  local accent = title.fg or string_hl.fg or fg
  local warn_fg = warn.fg or 0xf9e2af
  local border_fg = border.fg or accent

  define("ExplorerPopupNormal", { bg = bg, fg = fg })
  define("ExplorerPopupBorder", { bg = bg, fg = border_fg })
  define("ExplorerPopupTitle", { bg = bg, fg = accent, bold = true })
  define("ExplorerPopupFooter", { bg = bg, fg = muted, italic = true })
  define("ExplorerPopupPrompt", { bg = bg, fg = muted })
  define("ExplorerPopupValue", { bg = bg, fg = fg, bold = true })
  define("ExplorerPopupDangerBorder", { bg = bg, fg = warn_fg })
  define("ExplorerPopupDangerTitle", { bg = bg, fg = warn_fg, bold = true })
end

local function close_float(win, buf)
  if win and api.nvim_win_is_valid(win) then
    pcall(api.nvim_win_close, win, true)
  elseif buf and api.nvim_buf_is_valid(buf) then
    pcall(api.nvim_buf_delete, buf, { force = true })
  end
end

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
  local prompt_width = vim.fn.strdisplaywidth(prompt)
  local default_width = vim.fn.strdisplaywidth(default)
  local footer_width = vim.fn.strdisplaywidth(footer)
  local title_width = vim.fn.strdisplaywidth(title)
  -- Start with a generous minimum width (60) or derived from content
  local width =
    clamp(math.max(60, prompt_width + default_width + 10, footer_width + 6, title_width + 8), 60, editor_w - 8)

  local buf = require("custom.ui.buffer").create_raw(false, true)
  set_buf_option(buf, "buftype", "prompt")
  set_buf_option(buf, "bufhidden", "wipe")
  set_buf_option(buf, "swapfile", false)
  set_buf_option(buf, "modifiable", true)
  set_buf_option(buf, "filetype", "explorer_prompt")

  fn.prompt_setprompt(buf, prompt)

  local win = require("custom.ui.window").open_raw(buf, true, {
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
  -- Prevent premature scrolling by setting sidescrolloff to 0
  vim.wo[win].sidescrolloff = 0
  pcall(api.nvim_set_option_value, "statuscolumn", "", { win = win })
  pcall(api.nvim_set_option_value, "foldcolumn", "0", { win = win })
  set_win_option(win, "winblend", 8)

  local closed = false
  local function close()
    if closed then
      return
    end
    closed = true
    close_float(win, buf)
  end

  -- Dynamic Resize Strategy: Expand window width as user types to prevent prompt scrolling
  api.nvim_create_autocmd("TextChangedI", {
    group = api.nvim_create_augroup("ExplorerInput_" .. buf, { clear = false }),
    buffer = buf,
    callback = function()
      if not api.nvim_win_is_valid(win) then
        return
      end
      local line = api.nvim_get_current_line()
      local cur_w = api.nvim_win_get_width(win)
      local ew, _ = editor_size()

      local text_w = vim.fn.strdisplaywidth(line)
      local req_w = math.max(60, text_w + 4, footer_width + 6, title_width + 8)
      req_w = math.min(req_w, ew - 8)

      if req_w > cur_w then
        local new_col = math.max(0, math.floor((ew - req_w) / 2))
        local cur_cfg = api.nvim_win_get_config(win)
        api.nvim_win_set_config(win, {
          relative = "editor",
          width = req_w,
          col = new_col,
          row = cur_cfg.row,
        })
      end
    end,
  })

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

function M.input(opts, on_submit)
  opts = vim.tbl_extend("keep", opts or {}, {
    on_submit = on_submit,
  })
  prompt_float(opts)
end

function M.confirm(opts, on_confirm)
  opts = opts or {}
  local prompt = opts.prompt or "Confirm?"
  local footer = opts.footer or " y confirm   <Esc> cancel "

  prompt_float({
    title = opts.title or " Confirm ",
    prompt = prompt .. " (y/N): ",
    footer = footer,
    danger = opts.danger,
    on_submit = function(text)
      on_confirm(text and text:lower() == "y")
    end,
  })
end

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

local function open_text_popup(opts)
  M.ensure_hl()

  local lines = vim.deepcopy(opts.lines or {})
  local width = opts.width
  local editor_w, editor_h = editor_size()
  if not width then
    local max_line = 0
    for _, line in ipairs(lines) do
      max_line = math.max(max_line, vim.fn.strdisplaywidth(line))
    end
    width = clamp(max_line + 4, 44, editor_w - 8)
  end
  local height = clamp(#lines, 1, editor_h - 6)

  local buf = require("custom.ui.buffer").create_raw(false, true)
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  set_buf_option(buf, "bufhidden", "wipe")
  set_buf_option(buf, "modifiable", false)
  set_buf_option(buf, "filetype", opts.filetype or "explorer_popup")

  local win = require("custom.ui.window").open_raw(buf, true, {
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
  set_win_option(win, "winblend", 4)
  set_win_option(win, "cursorline", false)
  set_win_option(win, "wrap", false)
  pcall(api.nvim_set_option_value, "statuscolumn", "", { win = win })
  pcall(api.nvim_set_option_value, "foldcolumn", "0", { win = win })

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
      pcall(require("custom.ui.render").set_extmark, buf, ns, hl.row, hl.col_start, extmark)
    end
  end

  nvim_utils.bind_close_keys(buf, win, opts.close_keys or { "q", "<Esc>", "<CR>" }, { silent = true })
  return buf, win
end

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
      return string.format("%.1f KiB", n / 1024)
    elseif n < 1024 ^ 3 then
      return string.format("%.1f MiB", n / 1024 ^ 2)
    end
    return string.format("%.1f GiB", n / 1024 ^ 3)
  end

  local function fmt_time(seconds)
    return seconds and os.date("%Y-%m-%d %H:%M:%S", seconds) or "—"
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
    return string.format("%o (%s)", bit.band(mode, 0x1ff), table.concat(out))
  end

  local lines = {
    " Path         " .. fn.fnamemodify(item.path, ":~"),
    " Type         " .. stat.type .. (ls and ls.type == "link" and " (symlink)" or ""),
    " Size         " .. (item.is_dir and "—" or fmt_size(stat.size)),
    " Modified     " .. fmt_time(stat.mtime and stat.mtime.sec),
    " Created      " .. fmt_time(stat.birthtime and stat.birthtime.sec),
    " Accessed     " .. fmt_time(stat.atime and stat.atime.sec),
  }

  if fn.has("win32") == 0 then
    lines[#lines + 1] = " Permissions  " .. fmt_perm(stat.mode)
    lines[#lines + 1] = " Owner UID    " .. tostring(stat.uid)
    lines[#lines + 1] = " Group GID    " .. tostring(stat.gid)
    lines[#lines + 1] = " Hard links   " .. tostring(stat.nlink)
  end

  if ls and ls.type == "link" then
    lines[#lines + 1] = " Target       " .. (uv.fs_readlink(item.path) or "?")
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
    lines[#lines + 1] = " Git status   " .. (labels[ch] or ch)
  end

  local highlights = {
    { row = 0, col_start = 0, col_end = 13, group = "ExplorerPopupPrompt" },
  }
  for row = 1, #lines - 1 do
    highlights[#highlights + 1] = { row = row, col_start = 0, col_end = 13, group = "ExplorerPopupPrompt" }
  end

  open_text_popup({
    title = " 󰈔 " .. fn.fnamemodify(item.path, ":t") .. " ",
    footer = " q close ",
    filetype = "explorer_info",
    lines = lines,
    highlights = highlights,
    close_keys = { "q", "<Esc>", "<CR>" },
  })
end

function M.help()
  local km = cfg.get().keymaps
  local function key_label(key)
    return type(key) == "table" and table.concat(key, " / ") or (key or "—")
  end

  local sections = {
    {
      "Navigation",
      {
        { key_label(km.open), "open file or expand/collapse directory" },
        { key_label(km.close_dir), "collapse directory or jump to parent" },
        { key_label(km.go_up), "move explorer root to parent directory" },
        { key_label(km.toggle_width), "temporarily expand explorer width" },
        { key_label(km.expand_all), "expand one level of directories" },
        { key_label(km.collapse_all), "collapse every open directory" },
      },
    },
    {
      "Opening",
      {
        { key_label(km.vsplit), "open in a vertical split" },
        { key_label(km.split), "open in a horizontal split" },
        { key_label(km.tab), "open in a new tab" },
      },
    },
    {
      "File Ops",
      {
        { key_label(km.add), "create a file or directory" },
        { key_label(km.delete), "delete current item or marked items" },
        { key_label(km.rename), "rename or move current item" },
        { key_label(km.copy), "copy current item or marked items" },
        { key_label(km.move), "browse folders and paste selected items there" },
      },
    },
    {
      "Search And Marks",
      {
        { key_label(km.search), "focus the inline file filter" },
        { key_label(km.projects), "open the project picker" },
        { "<CR> in search", "keep the current filter" },
        { "<Esc> in search", "clear the current filter" },
        { key_label(km.mark), "toggle a file mark" },
      },
    },
    {
      "Git And Misc",
      {
        { key_label(km.git_stage), "stage current item or marks" },
        { key_label(km.git_restore), "restore current item or marks" },
        { key_label(km.copy_path), "copy a path variant to clipboard" },
        { key_label(km.file_info), "show metadata for the current item" },
        { key_label(km.toggle_hidden), "toggle dotfiles" },
        { key_label(km.refresh), "refresh tree and git state" },
        { key_label(km.help), "open this help window" },
        { key_label(km.quit), "close the explorer" },
      },
    },
  }

  local lines = {}
  local highlights = {}
  for _, section in ipairs(sections) do
    local section_row = #lines
    lines[#lines + 1] = " " .. section[1]
    highlights[#highlights + 1] = {
      row = section_row,
      col_start = 0,
      col_end = -1,
      group = "ExplorerPopupTitle",
      hl_eol = true,
    }
    for _, row in ipairs(section[2]) do
      local text = (" %-14s %s"):format(row[1], row[2])
      local line_row = #lines
      lines[#lines + 1] = text
      highlights[#highlights + 1] = {
        row = line_row,
        col_start = 1,
        col_end = 15,
        group = "ExplorerPopupValue",
      }
    end
    lines[#lines + 1] = ""
  end

  open_text_popup({
    title = " 󰍉 Explorer Help ",
    footer = " q close ",
    filetype = "explorer_help",
    width = 74,
    lines = lines,
    highlights = highlights,
    close_keys = { "q", "?", "<Esc>", "<CR>" },
  })
end

return M
