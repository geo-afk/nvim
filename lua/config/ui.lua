-- =============================================================================
--  config/ui.lua  ·  Visual & UX layer  (Neovim 0.12+)
-- =============================================================================

local ok_ui2, ui2 = pcall(require, "vim._core.ui2")
if not ok_ui2 then
  vim.notify("ui2 unavailable – upgrade to Neovim 0.12+", vim.log.levels.WARN)
  return
end

local msgs = require("vim._core.ui2.messages")

-- =============================================================================
--  Constants
-- =============================================================================

---Kinds whose messages are silently discarded.
---@type table<string, true>
local IGNORED_KINDS = {
  bufwrite = true,
  [""] = true,
  empty = true,
}

---Patterns whose matching messages are silently discarded.
---@type string[]
local SKIP_PATTERNS = {
  -- Write
  "%d+L, %d+B",
  -- Search
  "; after #%d+",
  "; before #%d+",
  "^[/?].*",
  "E486: Pattern not found:",
  -- Edit counts
  "%d+ less lines",
  "%d+ fewer lines",
  "%d+ more lines",
  "%d+ change;",
  "%d+ line less;",
  "%d+ more lines?;",
  "%d+ fewer lines;?",
  "1 more line",
  "1 line less",
  "^Hunk %d+ of %d+$",
  "Already at newest change",
  "Already at oldest change",
  "%d lines yanked",
  "no lines in buffer",
  -- Undo/redo
  "%d+ changes?;",
  " changes; before #",
  " changes; after #",
  " 1 change; before #",
  " 1 change; after #",
  -- Indent/move
  " lines moved",
  " lines indented",
}

---Per-kind display titles and highlight groups.
---@type table<string, { [1]: string, [2]: string }>
local KIND_TITLES = {
  emsg = { "  Error", "ErrorMsg" },
  echoerr = { "  Error", "ErrorMsg" },
  lua_error = { "  Error", "ErrorMsg" },
  rpc_error = { "  Error", "ErrorMsg" },
  wmsg = { "  Warning", "WarningMsg" },
  echo = { "  Info", "Normal" },
  echomsg = { "  Info", "Normal" },
  lua_print = { "  Print", "Normal" },
  search_cmd = { "  Search", "Normal" },
  search_count = { "  Search", "Normal" },
  undo = { "  Undo", "Normal" },
  shell_out = { "  Shell", "Normal" },
  shell_err = { "  Shell", "ErrorMsg" },
  shell_cmd = { "  Shell", "Normal" },
  quickfix = { "  Quickfix", "Normal" },
  progress = { "  Progress", "Normal" },
  typed_cmd = { "  Command", "Normal" },
  list_cmd = { "  List", "Normal" },
  verbose = { "  Verbose", "Comment" },
}

-- =============================================================================
--  Helpers
-- =============================================================================

---Flatten a message content table to a plain string.
---@param content any
---@return string
local function content_to_text(content)
  if type(content) ~= "table" then
    return tostring(content or "")
  end
  local parts = {}
  for _, chunk in ipairs(content) do
    if type(chunk) == "table" and chunk[2] then
      parts[#parts + 1] = chunk[2]
    end
  end
  return table.concat(parts)
end

---Return true if the message should be suppressed.
---@param kind string
---@param content any
---@return boolean
local function should_skip(kind, content)
  if IGNORED_KINDS[kind] then
    return true
  end
  local text = content_to_text(content)
  for _, pat in ipairs(SKIP_PATTERNS) do
    if text:find(pat) then
      return true
    end
  end
  return false
end

---Resolve the floating window title and highlight for a given kind.
---@param kind string
---@param content any
---@return string, string
local function resolve_title(kind, content)
  local entry = KIND_TITLES[kind]
  if entry then
    return entry[1], entry[2]
  end
  local text = vim.trim(content_to_text(content)):gsub("\n.*", "")
  if #text > 40 then
    text = text:sub(1, 37) .. "…"
  end
  return (text ~= "" and (" " .. text .. " ") or "  Message "), "Normal"
end

---Apply consistent window styling.
---@param win integer
---@param title string|nil
---@param hl string|nil
local function style_win(win, title, hl)
  if not (win and vim.api.nvim_win_is_valid(win)) then
    return
  end
  if vim.api.nvim_win_get_config(win).hide then
    return
  end

  local cfg = {
    border = "rounded",
    style = "minimal",
    title = title and { { title, hl or "Normal" } } or nil,
    title_pos = title and "center" or nil,
  }

  -- Position the toast (msg) window in the top-right corner.
  if win == (ui2.wins and ui2.wins.msg) then
    cfg.relative = "editor"
    cfg.anchor = "NE"
    cfg.row = 0
    cfg.col = vim.o.columns - 1
  end

  pcall(vim.api.nvim_win_set_config, win, cfg)
end

-- =============================================================================
--  ui2 enable
-- =============================================================================

ui2.enable({
  enable = true,
  msg = {
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
      progress = "msg",
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
    cmd = { height = 0.1 },
    dialog = { height = 0.4 },
    msg = { height = 0.3, timeout = 5000 },
    pager = { height = 0.4 },
  },
})

-- =============================================================================
--  Monkey-patches
-- =============================================================================

-- Track the current title/hl for use in set_pos.
local last_title, last_hl = nil, "Normal"

-- set_pos: single source of truth for window placement and styling.
local orig_set_pos = msgs.set_pos
msgs.set_pos = function(tgt)
  orig_set_pos(tgt)
  local win = ui2.wins and ui2.wins[tgt or "msg"]
  if win then
    style_win(win, last_title, last_hl)
  end
end

-- msg_show: filter, resolve title, then delegate.
local orig_msg_show = msgs.msg_show
msgs.msg_show = function(kind, content, replace_last, history, append, id, trigger)
  if should_skip(kind, content) then
    return
  end

  last_title, last_hl = resolve_title(kind, content)

  local tgt = ui2.cfg.msg.targets[kind]
    or (trigger and trigger ~= "" and ui2.cfg.msg.targets[trigger])
    or ui2.cfg.msg.target

  msgs.show_msg(tgt, kind, content, replace_last, append, id)
  msgs.set_pos(tgt)
end

-- show_msg: overflow detection – large content goes to pager.
local orig_show_msg = msgs.show_msg
msgs.show_msg = function(tgt, kind, content, replace_last, append, id)
  if tgt == "msg" then
    local text = content_to_text(content)
    local lines = vim.split(text, "\n")
    local width = 0
    for _, line in ipairs(lines) do
      width = math.max(width, vim.api.nvim_strwidth(line))
    end
    if width > math.floor(vim.o.columns * 0.75) or #lines > 15 then
      vim.schedule(function()
        orig_show_msg("pager", kind, content, replace_last, append, id)
        msgs.set_pos("pager")
      end)
      return
    end
  end
  orig_show_msg(tgt, kind, content, replace_last, append, id)
end

-- =============================================================================
--  LSP progress (stable single-toast)
-- =============================================================================

vim.api.nvim_create_autocmd("LspProgress", {
  group = vim.api.nvim_create_augroup("LspProgressUI2", { clear = true }),
  callback = function(ev)
    local value = ev.data.params.value
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if not client or not value then
      return
    end

    local is_end = value.kind == "end"
    local pct = value.percentage and ("%3d%%"):format(value.percentage) or "---%"
    local label = (value.message ~= "" and value.message or value.title or ""):sub(1, 22)

    vim.api.nvim_echo({ { ("%-10s │ %-22s │ %s"):format(client.name:sub(1, 10), label, pct) } }, false, {
      id = "lsp.progress",
      kind = "progress",
      source = "vim.lsp",
      status = is_end and "success" or "running",
    })
  end,
})

-- =============================================================================
--  Deferred: load showcase commands + extra highlights
-- =============================================================================

vim.schedule(function()
  pcall(function()
    require("config.ui_showcase").setup()
  end)
  vim.api.nvim_set_hl(0, "@module.last", { link = "Type", bold = true, italic = true })
end)
