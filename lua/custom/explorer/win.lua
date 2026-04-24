-- custom/explorer/win.lua
-- Window creation, highlight groups, keymaps.

local S = require("custom.explorer.state")
local cfg = require("custom.explorer.config")
local git = require("custom.explorer.git")
local marks = require("custom.explorer.marks")
local icons = require("custom.explorer.icons")
local api = vim.api

local M = {}

-- ── Colour helpers ────────────────────────────────────────────────────────

local function unpack_rgb(c)
  return math.floor(c / 0x10000) % 0x100, math.floor(c / 0x100) % 0x100, c % 0x100
end

local function blend(a, b, t)
  local ar, ag, ab_ = unpack_rgb(a)
  local br, bg, bb = unpack_rgb(b)
  local lerp = function(x, y)
    return math.floor(x * t + y * (1 - t) + 0.5)
  end
  return lerp(ar, br) * 0x10000 + lerp(ag, bg) * 0x100 + lerp(ab_, bb)
end

local function nudge(c, delta)
  local r, g, b = unpack_rgb(c)
  local clamp = function(v)
    return math.max(0, math.min(255, v))
  end
  return clamp(r + delta) * 0x10000 + clamp(g + delta) * 0x100 + clamp(b + delta)
end

local function get(name)
  local ok, h = pcall(api.nvim_get_hl, 0, { name = name, link = false })
  return ok and h or {}
end

local function def(name, opts)
  pcall(api.nvim_set_hl, 0, name, opts)
end

local function fg_of(...)
  for _, n in ipairs({ ... }) do
    local h = get(n)
    if h.fg then
      return h.fg
    end
  end
end

-- ── Highlight system ──────────────────────────────────────────────────────

function M.ensure_hl()
  local ok, ex = pcall(api.nvim_get_hl, 0, { name = "ExplorerNormal" })
  if ok and ex and next(ex) then
    return
  end

  local normal = get("Normal")
  local float_ = get("NormalFloat")
  local comment = get("Comment")
  local cursor = get("CursorLine")
  local pmenu = get("Pmenu")

  local editor_bg = normal.bg or 0x1e1e2e
  local sidebar_bg = float_.bg or pmenu.bg or nudge(editor_bg, -8)
  if sidebar_bg == editor_bg then
    sidebar_bg = nudge(editor_bg, -10)
  end

  local normal_fg = normal.fg or 0xcdd6f4
  local dim_fg = comment.fg or 0x585b70
  local accent = fg_of("Function", "@function", "Special", "Statement") or 0xcba6f7
  local dir_fg = fg_of("Directory", "@namespace", "Special") or 0x89b4fa
  local str_fg = fg_of("String", "@string", "Constant") or 0xa6e3a1
  local keyword_fg = fg_of("Keyword", "@keyword", "Statement") or 0xf38ba8
  local number_fg = fg_of("Number", "@number", "Constant") or 0xfab387
  local type_fg = fg_of("Type", "@type", "StorageClass") or 0x94e2d5
  local prop_fg = fg_of("Identifier", "@property", "Special") or 0x89dceb
  local note_fg = fg_of("DiagnosticInfo", "MoreMsg", "Special") or 0x74c7ec
  local warn_fg = fg_of("DiagnosticWarn", "WarningMsg", "Special") or 0xf9e2af
  local err_fg = fg_of("DiagnosticError", "ErrorMsg", "Special") or 0xf38ba8
  local git_fg = fg_of("DiffChange", "GitSignsChange", "Conditional") or 0xf9e2af

  -- ── Core sidebar ────────────────────────────────────────────────────
  def("ExplorerNormal", { bg = sidebar_bg, fg = normal_fg })
  local cursor_bg = cursor.bg or blend(accent, sidebar_bg, 0.10)
  def("ExplorerCursorLine", { bg = cursor_bg })
  def("ExplorerDirectory", { fg = dir_fg, bold = true })
  def("ExplorerFile", { fg = blend(normal_fg, sidebar_bg, 0.18) })
  def("ExplorerFileAccent", { fg = normal_fg, bold = true })
  def("ExplorerConnector", { fg = blend(dim_fg, sidebar_bg, 0.35) })

  -- ── Inline search bar ────────────────────────────────────────────────
  local search_bg = blend(accent, sidebar_bg, 0.055)
  local search_active_bg = blend(accent, sidebar_bg, 0.10)

  def("ExplorerSearchBg", { bg = search_bg, fg = normal_fg })
  def("ExplorerSearchBgActive", { bg = search_active_bg, fg = normal_fg })
  def("ExplorerSearchIcon", { fg = blend(accent, dim_fg, 0.40), bg = search_bg })
  def("ExplorerSearchIconActive", { fg = accent, bold = true, bg = search_active_bg })
  def("ExplorerSearchBorder", { fg = blend(dim_fg, sidebar_bg, 0.55) })
  def("ExplorerSearchBorderFilter", { fg = blend(accent, dim_fg, 0.30) })
  def("ExplorerSearchBorderActive", { fg = accent })
  def("ExplorerSearchTitle", { fg = blend(accent, normal_fg, 0.20), bold = true })
  def("ExplorerSearchPlaceholder", { fg = blend(dim_fg, sidebar_bg, 0.6), italic = true, bg = search_bg })
  def("ExplorerSearchActiveText", { fg = str_fg, bold = true })
  def("ExplorerSearchCount", { fg = blend(accent, dim_fg, 0.5), italic = true })
  def("ExplorerSearchCountActive", { fg = accent, bold = true, bg = search_active_bg })
  def("ExplorerSearchCursor", { bg = blend(accent, sidebar_bg, 0.22) })
  def("ExplorerSearchMatch", { fg = accent, bold = true, underline = true })

  -- ── File-type icons ──────────────────────────────────────────────────
  def("ExplorerIconDir", { fg = dir_fg, bold = true })
  def("ExplorerIconDirOpen", { fg = blend(dir_fg, accent, 0.45), bold = true })
  def("ExplorerIconLink", { fg = note_fg, italic = true })
  def("ExplorerIconDefault", { fg = blend(normal_fg, sidebar_bg, 0.12) })
  def("ExplorerIconLua", { fg = note_fg })
  def("ExplorerIconVim", { fg = warn_fg })
  def("ExplorerIconShell", { fg = str_fg })
  def("ExplorerIconPowerShell", { fg = prop_fg })
  def("ExplorerIconWeb", { fg = keyword_fg })
  def("ExplorerIconTypeScript", { fg = prop_fg })
  def("ExplorerIconData", { fg = number_fg })
  def("ExplorerIconCompiled", { fg = type_fg })
  def("ExplorerIconDotnet", { fg = type_fg })
  def("ExplorerIconJava", { fg = keyword_fg })
  def("ExplorerIconGo", { fg = note_fg })
  def("ExplorerIconRust", { fg = number_fg })
  def("ExplorerIconPython", { fg = warn_fg })
  def("ExplorerIconRuby", { fg = err_fg })
  def("ExplorerIconPhp", { fg = keyword_fg })
  def("ExplorerIconDocs", { fg = blend(str_fg, normal_fg, 0.75) })
  def("ExplorerIconImage", { fg = blend(keyword_fg, warn_fg, 0.45) })
  def("ExplorerIconMedia", { fg = blend(prop_fg, accent, 0.35) })
  def("ExplorerIconArchive", { fg = warn_fg })
  def("ExplorerIconDatabase", { fg = number_fg })
  def("ExplorerIconLog", { fg = blend(dim_fg, normal_fg, 0.3) })
  def("ExplorerIconLock", { fg = err_fg })
  def("ExplorerIconGit", { fg = git_fg })
  def("ExplorerIconDocker", { fg = note_fg })
  def("ExplorerIconPackage", { fg = keyword_fg })
  def("ExplorerIconEnv", { fg = str_fg })
  def("ExplorerIconBuild", { fg = warn_fg })

  -- ── Winbar ───────────────────────────────────────────────────────────
  def("ExplorerWinbar", { bg = sidebar_bg, fg = blend(accent, normal_fg, 0.25) })
  def("ExplorerWinbarBranch", { bg = sidebar_bg, fg = blend(dim_fg, normal_fg, 0.5), italic = true })

  -- ── Git + marks ──────────────────────────────────────────────────────
  git.setup_hl()
  marks.setup_hl()
end

function M.reset_hl()
  -- NOTE: Explorer*Line groups have been intentionally removed.
  -- Git status is now shown only via the sign-column icon; there are no
  -- line-level background tints or filename colour overrides.
  local names = {
    "ExplorerNormal",
    "ExplorerCursorLine",
    "ExplorerDirectory",
    "ExplorerFile",
    "ExplorerFileAccent",
    "ExplorerConnector",
    "ExplorerSearchBg",
    "ExplorerSearchBgActive",
    "ExplorerSearchBorder",
    "ExplorerSearchBorderFilter",
    "ExplorerSearchBorderActive",
    "ExplorerSearchTitle",
    "ExplorerSearchIcon",
    "ExplorerSearchIconActive",
    "ExplorerSearchPlaceholder",
    "ExplorerSearchActiveText",
    "ExplorerSearchCount",
    "ExplorerSearchCountActive",
    "ExplorerSearchCursor",
    "ExplorerSearchMatch",
    "ExplorerWinbar",
    "ExplorerWinbarBranch",
    "ExplorerPopupNormal",
    "ExplorerPopupBorder",
    "ExplorerPopupTitle",
    "ExplorerPopupFooter",
    "ExplorerPopupPrompt",
    "ExplorerPopupValue",
    "ExplorerPopupDangerBorder",
    "ExplorerPopupDangerTitle",
    "ExplorerGitAdded",
    "ExplorerGitModified",
    "ExplorerGitDeleted",
    "ExplorerGitRenamed",
    "ExplorerGitUntracked",
    "ExplorerGitConflict",
    "ExplorerGitIgnored",
    "ExplorerMark",
  }
  vim.list_extend(names, icons.GROUPS)
  for _, name in ipairs(names) do
    pcall(api.nvim_set_hl, 0, name, {})
  end
end

-- ── Buffer ────────────────────────────────────────────────────────────────

function M.make_buf()
  local buf = api.nvim_create_buf(false, true)
  pcall(api.nvim_buf_set_name, buf, "explorer://")
  local bo = vim.bo[buf]
  bo.buftype = "nofile"
  bo.bufhidden = "hide"
  bo.buflisted = false
  bo.filetype = "explorer"
  bo.modifiable = false
  bo.swapfile = false
  bo.omnifunc = ""
  bo.completefunc = ""
  vim.b[buf].cmp_enabled = false
  vim.b[buf].completion_enabled = false
  vim.b[buf].completion = false
  return buf
end

-- ── Window ────────────────────────────────────────────────────────────────

-- Async git branch: shows the root name immediately, then adds the branch
-- once the git process responds — never blocks the UI thread.
local function git_branch_async(root, callback)
  vim.system(
    { "git", "-C", root, "branch", "--show-current" },
    { text = true },
    vim.schedule_wrap(function(out)
      if out.code ~= 0 or not out.stdout or vim.trim(out.stdout) == "" then
        callback(nil)
      else
        callback(vim.trim(out.stdout))
      end
    end)
  )
end

local function winbar_string(root_name, branch)
  local bar = "%#ExplorerWinbar# 󰉋 " .. root_name
  if branch then
    bar = bar .. " %#ExplorerWinbarBranch#   " .. branch
  end
  return bar .. "%#ExplorerWinbar# "
end

local function refresh_winbar_async()
  local root = S.root or vim.fn.getcwd()
  local root_name = vim.fn.fnamemodify(root, ":t")
  if S.win and api.nvim_win_is_valid(S.win) then
    pcall(function()
      vim.wo[S.win].winbar = winbar_string(root_name, nil)
    end)
  end
  git_branch_async(root, function(branch)
    if not (S.win and api.nvim_win_is_valid(S.win)) then
      return
    end
    pcall(function()
      vim.wo[S.win].winbar = winbar_string(root_name, branch)
    end)
  end)
end

function M.apply_window_options(win)
  if not (win and api.nvim_win_is_valid(win)) then
    return
  end
  local wo = vim.wo[win]
  wo.number = false
  wo.relativenumber = false
  wo.signcolumn = "no"
  wo.winfixwidth = true
  wo.wrap = false
  wo.spell = false
  wo.list = false
  wo.cursorline = true
  wo.fillchars = "eob: "
  pcall(function()
    wo.statuscolumn = ""
  end)
  pcall(function()
    wo.foldcolumn = "0"
  end)
  wo.winhl = table.concat({
    "Normal:ExplorerNormal",
    "CursorLine:ExplorerCursorLine",
    "WinBar:ExplorerWinbar",
    "WinBarNC:ExplorerWinbar",
  }, ",")
end

function M.make_win(buf)
  M.ensure_hl()
  local c = cfg.get()
  local side = c.side == "right" and "botright" or "topleft"
  vim.cmd(side .. " " .. c.width .. "vsplit")
  local win = api.nvim_get_current_win()
  api.nvim_win_set_buf(win, buf)
  M.apply_window_options(win)
  S.icon_fn = icons.resolve()
  -- Async winbar: root shows immediately; branch appended once git replies
  refresh_winbar_async()
  return win
end

function M.update_winbar()
  refresh_winbar_async()
end

-- ── Keymaps ───────────────────────────────────────────────────────────────

function M.setup_keymaps(buf)
  local km = cfg.get().keymaps
  local A = require("custom.explorer.actions")
  local opts = { noremap = true, silent = true, buffer = buf }

  local function map(keys, action)
    if type(keys) == "string" then
      keys = { keys }
    end
    for _, k in ipairs(keys) do
      if k and k ~= "" then
        vim.keymap.set("n", k, action, opts)
      end
    end
  end

  map(km.open, A.open_or_toggle)
  map(km.close_dir, A.close_dir)
  map(km.go_up, A.go_up)
  map(km.vsplit, A.vsplit)
  map(km.split, A.split)
  map(km.tab, A.tab_open)
  map(km.add, A.add)
  map(km.delete, A.delete)
  map(km.rename, A.rename)
  map(km.copy, A.copy)
  map(km.move, A.move)
  map(km.toggle_hidden, A.toggle_hidden)
  map(km.refresh, A.refresh)
  map(km.add_project, A.add_project)
  map(km.copy_path, A.copy_path)
  map(km.file_info, A.file_info)
  map(km.mark, A.toggle_mark)
  map(km.collapse_all, A.collapse_all)
  map(km.expand_all, function()
    A.expand_all(1)
  end)
  map(km.git_stage, A.git_stage)
  map(km.git_restore, A.git_restore)
  map(km.help, A.show_help)
  map(km.search, function()
    require("custom.explorer.search").activate()
  end)
  map(km.projects, function()
    require("custom.explorer.projects").open()
  end)
  map(km.quit, function()
    if S.close_fn then
      S.close_fn()
    end
  end)
end

return M
