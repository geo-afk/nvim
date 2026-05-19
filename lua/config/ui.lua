-- =============================================================================
--  config/ui.lua  ·  Visual & UX layer
--
--  Covers:
--    • ui2 (experimental redesigned message/cmdline UI)
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

local ok_ui2, ui2 = pcall(require, "vim._core.ui2")
if ok_ui2 then
  local msgs = require("vim._core.ui2.messages")

  -- ── Config ──────────────────────────────────────────────────────────

  local IGNORED_KINDS = {
    bufwrite = true,
    [""] = true,
    empty = true,
  }

  local SKIP_PATTERNS = {
    -- Write
    "%d+L, %d+B",
    -- Search
    "; after #%d+",
    "; before #%d+",
    "^[/?].*",
    "E486: Pattern not found:",
    -- Edit
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
    -- Undo/Redo
    "%d+ changes?;",
    " changes; brefore #",
    " changes; after #",
    " 1 change; before #",
    " 1 change; after #",
    -- Move lines
    " lines moved",
    " lines indented",
  }

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

  -- ── State ────────────────────────────────────────────────────────────

  local last_title = nil
  local last_hl = "Normal"

  -- ── Helpers ─────────────────────────────────────────────────────────

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

  local function resolve_title(kind, content)
    local entry = KIND_TITLES[kind]
    if entry then
      return entry[1], entry[2]
    end
    local text = vim.trim(content_to_text(content)):gsub("\n.*", "")
    if #text > 40 then
      text = text:sub(1, 37) .. "…"
    end
    return text ~= "" and (" " .. text .. " ") or "  Message ", "Normal"
  end

  local function apply_win_config(win)
    if not (win and vim.api.nvim_win_is_valid(win)) then
      return
    end
    if vim.api.nvim_win_get_config(win).hide then
      return
    end

    local config = {
      border = "rounded",
      style = "minimal",
      title = last_title and { { last_title, last_hl } } or nil,
      title_pos = last_title and "center" or nil,
    }

    -- Specific overrides for the msg (toast) window
    if win == (ui2.wins and ui2.wins.msg) then
      config.relative = "editor"
      config.anchor = "NE"
      config.row = 1
      config.col = vim.o.columns - 1
    end

    pcall(vim.api.nvim_win_set_config, win, config)
  end

  -- ── ui2 enable ──────────────────────────────────────────────────────

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

  -- ── Wrap set_pos: the single source of truth for msg window placement ─

  local orig_set_pos = msgs.set_pos
  msgs.set_pos = function(tgt)
    orig_set_pos(tgt)
    local win = ui2.wins and ui2.wins[tgt or "msg"]
    if win then
      apply_win_config(win)
    end
  end

  -- ── Wrap msg_show: filtering + title tracking ─────────────────────────

  local orig_msg_show = msgs.msg_show
  msgs.msg_show = function(kind, content, replace_last, history, append, id, trigger)
    if should_skip(kind, content) then
      return
    end

    local title, hl = resolve_title(kind, content)
    last_title, last_hl = title, hl

    local tgt = ui2.cfg.msg.targets[kind]
      or (trigger ~= "" and ui2.cfg.msg.targets[trigger])
      or ui2.cfg.msg.targets[trigger]
      or ui2.cfg.msg.target

    msgs.show_msg(tgt, kind, content, replace_last, append, id)
    msgs.set_pos(tgt)
  end

  -- ── Wrap show_msg: dynamic routing for long content ───────────────────

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
          msgs.show_msg("pager", kind, content, replace_last, append, id)
          msgs.set_pos("pager")
        end)
        return
      end
    end
    orig_show_msg(tgt, kind, content, replace_last, append, id)
  end

  -- ── LSP progress integration ────────────────────────────────────────

  vim.api.nvim_create_autocmd("LspProgress", {
    group = vim.api.nvim_create_augroup("LspProgressUI2", { clear = true }),
    callback = function(ev)
      local value = ev.data.params.value
      local client = vim.lsp.get_client_by_id(ev.data.client_id)
      if not client or not value then
        return
      end

      local is_end = value.kind == "end"
      local percentage = value.percentage and string.format("%3d%%", value.percentage) or "---%"
      local title = value.title or ""
      local message = value.message or ""

      -- Stable formatting: fixed widths for name and message prevent window jumping/resizing
      local display_msg = string.format("%-10s │ %-22s │ %s", client.name:sub(1, 10), (message ~= "" and message or title):sub(1, 22), percentage)

      vim.api.nvim_echo({ { display_msg } }, false, {
        id = "lsp.progress", -- Use a single ID to ensure we only have one "Progress" toast at a time
        kind = "progress",
        source = "vim.lsp",
        status = is_end and "success" or "running",
      })
    end,
  })
else
  vim.notify("ui2 is not available in this Neovim build; upgrade to 0.12+", vim.log.levels.WARN)
end

-- Load the showcase in the background (commands only)
vim.schedule(function()
  pcall(function()
    require("config.ui_showcase").setup()
  end)

  -- Go Import highlights
  vim.api.nvim_set_hl(0, "@module.last", { link = "Type", bold = true, italic = true })
end)
