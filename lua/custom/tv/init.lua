-- =============================================================================
--  custom/tv/init.lua  ·  Television fuzzy finder integration for Neovim 0.12
-- =============================================================================
--
--  Architecture
--  ────────────
--  Television (tv) is an external terminal UI process. Because Neovim cannot
--  capture interactive TUI output directly via vim.system(), the standard
--  integration technique is:
--
--    1. Write selected entries to a temp file via `tv --output <path>`.
--    2. Open tv in a full-screen floating terminal (using custom.float_term).
--    3. On process exit, read the temp file, pass entries to the channel action.
--    4. Clean up the temp file.
--
--  Channel Picker
--  ──────────────
--  `M.open_picker()` renders a custom.ui.picker floating window listing all
--  registered channels. Selecting one launches `M.open(channel_name)`.
--
--  Public API
--  ──────────
--    M.setup(opts)           Configure keybindings and global options.
--    M.open(channel, opts)   Launch tv for the given channel name.
--    M.open_picker()         Open the channel picker UI.
--    M.actions               Re-export of custom.tv.actions for user config.
--    M.channels              Re-export of custom.tv.channels table.
--
--  User Configuration (opts to M.setup)
--  ──────────────────────────────────────
--    tv_binary       string    Path/name of the tv binary (default: "tv")
--    keybindings     bool      Register default per-channel keybindings (default: true)
--    picker_key      string    Key to open the channel picker (default: "<leader>tv")
--    window          table     Overrides for the floating terminal dimensions:
--      width_ratio   number    0-1 fraction of editor width  (default: 0.92)
--      height_ratio  number    0-1 fraction of editor height (default: 0.92)
--    channels        table?    Per-channel overrides, keyed by channel name:
--                              { action = fn, keybinding = string }
-- =============================================================================

local M = {}

-- ─── Lazy-loaded dependencies ─────────────────────────────────────────────────

local function get_term()
  local ok, term = pcall(require, "custom.float_term.term")
  if not ok then
    error("[tv] custom.float_term.term is required but not found")
  end
  return term
end

local function get_ui()
  return require("custom.ui")
end

-- ─── Module state ─────────────────────────────────────────────────────────────

---@type table<string, TvChannel>
local channel_map = {}

local config = {
  tv_binary = "tv",
  keybindings = true,
  picker_key = "<leader>tv",
  window = {
    width_ratio = 0.92,
    height_ratio = 0.92,
  },
  channels = {},
}

-- ─── Internal helpers ─────────────────────────────────────────────────────────

--- Build the resolved channel list, applying any user overrides.
---@return TvChannel[]
local function resolved_channels()
  local defs = require("custom.tv.channels")
  local result = {}
  for _, ch in ipairs(defs) do
    local override = config.channels[ch.name] or {}
    result[#result + 1] = vim.tbl_extend("force", ch, override)
  end
  return result
end

--- Populate `channel_map` from resolved channel list.
local function build_channel_map()
  channel_map = {}
  for _, ch in ipairs(resolved_channels()) do
    channel_map[ch.name] = ch
  end
end

-- ─── Core: launch tv ─────────────────────────────────────────────────────────

--- Launch the television TUI for the given channel, read its output, and
--- dispatch the appropriate action handler.
---
---@param channel_name string  TV channel identifier (e.g. "files", "git-branch")
---@param opts         table?  { action = fun(entries), title = string }
function M.open(channel_name, opts)
  opts = opts or {}

  if vim.fn.executable(config.tv_binary) == 0 then
    vim.notify(
      string.format("[tv] Binary '%s' not found in PATH. Install television first.", config.tv_binary),
      vim.log.levels.ERROR
    )
    return
  end

  local ch = channel_map[channel_name] or { name = channel_name }
  local action = opts.action or ch.action or function() end
  local title = opts.title or (ch.icon and (ch.icon .. "  " .. (ch.label or channel_name)) or channel_name)

  -- Build command without --output
  local cmd = { config.tv_binary, channel_name }

  local term = get_term()
  local origin_win = vim.api.nvim_get_current_win()

  term.setup({
    width_ratio = config.window.width_ratio,
    height_ratio = config.window.height_ratio,
    border = nil,
    title = " " .. title .. " ",
    zindex = 300,
  })

  -- Store stdout data
  local stdout_data = {}

  term.create_terminal(cmd, {
    title = " " .. title .. " ",
    on_output = function(data)
      if data then
        stdout_data[#stdout_data + 1] = data
      end
    end,
    on_exit = function(exit_code)
      vim.schedule(function()
        if vim.api.nvim_win_is_valid(origin_win) then
          vim.api.nvim_set_current_win(origin_win)
        end
      end)

      if exit_code ~= 0 then
        return
      end

      vim.schedule(function()
        local raw = table.concat(stdout_data, "")
        if raw == "" then
          return
        end

        local entries = {}
        for line in raw:gmatch("[^\r\n]+") do
          if line ~= "" then
            entries[#entries + 1] = line
          end
        end

        if #entries > 0 then
          pcall(action, entries)
        end
      end)
    end,
  })
end
-- ─── Channel picker ───────────────────────────────────────────────────────────

--- Open a floating channel picker built with custom.ui.picker.
--- Selecting a channel launches M.open() for that channel.
function M.open_picker()
  local channels = resolved_channels()

  -- Format items for display: icon + label + dim description
  ---@param ch TvChannel
  local function format_item(ch)
    local icon = ch.icon and (ch.icon .. " ") or "  "
    local label = ch.label or ch.name
    local pad = string.rep(" ", math.max(1, 22 - vim.fn.strdisplaywidth(label)))
    return icon .. label .. pad .. ch.desc
  end

  local ui = get_ui()

  -- Build lines separately so we can pass highlights.
  local lines = {}
  local highlights = {}
  for i, ch in ipairs(channels) do
    local line = "  " .. format_item(ch)
    lines[#lines + 1] = line
    -- Highlight the icon+name portion in a distinct color.
    highlights[#highlights + 1] = {
      row = i - 1,
      col_start = 2,
      col_end = 2 + vim.fn.strdisplaywidth((ch.icon or "") .. " " .. (ch.label or ch.name)),
      group = "Function",
    }
  end

  ui.picker({
    title = "  Television Channels ",
    title_pos = "center",
    items = channels,
    format_item = format_item,
    lines = lines,
    highlights = highlights,
    min_width = 52,
    max_width = 72,
    border = "rounded",
    cursorline = true,
    on_confirm = function(ch)
      if ch then
        -- Small defer so the picker window fully closes before tv opens.
        vim.defer_fn(function()
          M.open(ch.name)
        end, 10)
      end
    end,
  })
end

-- ─── Setup ────────────────────────────────────────────────────────────────────

---@param opts table?  User configuration (see module header for schema)
function M.setup(opts)
  config = vim.tbl_deep_extend("force", config, opts or {})
  build_channel_map()

  -- Register picker keybinding.
  if config.picker_key and config.picker_key ~= "" then
    vim.keymap.set("n", config.picker_key, M.open_picker, {
      desc = "tv: channel picker",
      silent = true,
    })
  end

  -- Register per-channel keybindings when enabled.
  if config.keybindings then
    for _, ch in ipairs(resolved_channels()) do
      local key = (config.channels[ch.name] and config.channels[ch.name].keybinding) or ch.keybinding
      if key and key ~= "" then
        local ch_name = ch.name -- capture for closure
        vim.keymap.set("n", key, function()
          M.open(ch_name)
        end, {
          desc = "tv: " .. (ch.label or ch_name),
          silent = true,
        })
      end
    end
  end

  -- Register :Tv user command with channel tab-completion.
  vim.api.nvim_create_user_command("Tv", function(cmd_opts)
    local arg = vim.trim(cmd_opts.args)
    if arg == "" then
      M.open_picker()
    else
      M.open(arg)
    end
  end, {
    nargs = "?",
    desc = "Open television fuzzy finder (optionally with a channel name)",
    complete = function(arg_lead)
      local completions = {}
      for _, ch in ipairs(resolved_channels()) do
        if vim.startswith(ch.name, arg_lead) then
          completions[#completions + 1] = ch.name
        end
      end
      return completions
    end,
  })
end

-- ─── Public re-exports ────────────────────────────────────────────────────────

M.actions = require("custom.tv.actions")
M.channels = require("custom.tv.channels")

return M
