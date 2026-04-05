--- lsp-keymapper/ui.lua
--- Floating-window UI for browsing LSP capabilities, inspecting existing
--- keymaps, filtering, and interactively assigning new mappings.
---
--- The browser renders two sections:
---   1. Known Capabilities   - entries defined in the capabilities registry
---   2. Discovered Caps      - anything extra found in server_capabilities at
---                             runtime (e.g. ts_ls executeCommandProvider,
---                             workspace.fileOperations, etc.)

local M = {}

-- Derive sibling module path from the current file's dotted name.
-- e.g. "custom.lsp_keymapper.ui" -> base = "custom.lsp_keymapper"
local _BASE = (...):match '^(.+)%.[^.]+$' or (...)

local caps = require(_BASE .. '.capabilities')
local keymaps = require(_BASE .. '.keymap')
local nvim_utils = require('utils.nvim')

-- ─────────────────────────────────────────────────────────────────────────────
-- Constants
-- ─────────────────────────────────────────────────────────────────────────────

local TITLE = ' LSP Capability Mapper '
local NS = vim.api.nvim_create_namespace 'lsp_keymapper'

local HL_HEADER = 'LspKeyHeader' -- section headers / dividers
local HL_MAPPED = 'LspKeyMapped' -- known cap that is already bound
local HL_FREE = 'LspKeyFree' -- known cap that is not yet bound
local HL_DIM = 'LspKeyDim' -- supplementary text (description, hint)
local HL_KEY = 'LspKeyKey' -- capability label
local HL_DISCOVERED = 'LspKeyDiscovered' -- discovered cap WITH an auto-handler
local HL_NO_HANDLER = 'LspKeyNoHandler' -- discovered cap WITHOUT a handler

-- ─────────────────────────────────────────────────────────────────────────────
-- Internal helpers
-- ─────────────────────────────────────────────────────────────────────────────

local function setup_highlights()
  vim.api.nvim_set_hl(0, HL_HEADER, { link = 'Title', default = true })
  vim.api.nvim_set_hl(0, HL_MAPPED, { link = 'DiagnosticOk', default = true })
  vim.api.nvim_set_hl(0, HL_FREE, { link = 'String', default = true })
  vim.api.nvim_set_hl(0, HL_DIM, { link = 'Comment', default = true })
  vim.api.nvim_set_hl(0, HL_KEY, { link = 'Keyword', default = true })
  vim.api.nvim_set_hl(0, HL_DISCOVERED, { link = 'DiagnosticWarn', default = true })
  vim.api.nvim_set_hl(0, HL_NO_HANDLER, { link = 'DiagnosticError', default = true })
end

local function win_geometry(width_pct, height_pct)
  local ew = vim.o.columns
  local eh = vim.o.lines
  local w = math.floor(ew * width_pct)
  local h = math.floor(eh * height_pct)
  local col = math.floor((ew - w) / 2)
  local row = math.floor((eh - h) / 2)
  return col, row, w, h
end

--- Strip all newline and carriage-return characters from a string.
--- Every line passed to nvim_buf_set_lines must be free of embedded newlines
--- or the API raises "replacement string contains newlines".
---
--- @param  s string
--- @return string
local function sanitize_line(s)
  return (tostring(s):gsub('[\n\r]', ' '))
end

local function open_float(title, lines)
  local col, row, w, h = win_geometry(0.72, 0.78)

  local buf = vim.api.nvim_create_buf(false, true)
  -- Sanitize every line: nvim_buf_set_lines rejects strings with embedded newlines
  local safe_lines = {}
  for _, l in ipairs(lines) do
    table.insert(safe_lines, sanitize_line(l))
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, safe_lines)
  vim.api.nvim_set_option_value('buftype', 'nofile', { buf = buf })
  vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = buf })
  vim.api.nvim_set_option_value('modifiable', false, { buf = buf })
  vim.api.nvim_set_option_value('filetype', 'lsp-keymapper', { buf = buf })

  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    col = col,
    row = row,
    width = w,
    height = h,
    style = 'minimal',
    border = 'rounded',
    title = title,
    title_pos = 'center',
  })

  vim.api.nvim_set_option_value('wrap', false, { win = win })
  vim.api.nvim_set_option_value('cursorline', true, { win = win })

  return buf, win
end

--- Apply syntax highlights to every rendered entry.
---
--- Entry shape (all fields optional except row):
---   row, is_header, is_discovered, is_mapped, has_handler, label_end
---
--- @param buf     integer
--- @param entries table[]
local function apply_highlights(buf, entries)
  for _, e in ipairs(entries) do
    local row = e.row
    if e.is_header then
      vim.api.nvim_buf_add_highlight(buf, NS, HL_HEADER, row, 0, -1)
    elseif e.is_discovered then
      local icon_hl = e.has_handler and HL_DISCOVERED or HL_NO_HANDLER
      vim.api.nvim_buf_add_highlight(buf, NS, icon_hl, row, 0, 4)
      vim.api.nvim_buf_add_highlight(buf, NS, HL_KEY, row, 4, e.label_end)
      vim.api.nvim_buf_add_highlight(buf, NS, HL_DIM, row, e.label_end, -1)
    elseif e.is_mapped then
      vim.api.nvim_buf_add_highlight(buf, NS, HL_MAPPED, row, 0, 4)
      vim.api.nvim_buf_add_highlight(buf, NS, HL_KEY, row, 4, e.label_end)
      vim.api.nvim_buf_add_highlight(buf, NS, HL_DIM, row, e.label_end, -1)
    else
      vim.api.nvim_buf_add_highlight(buf, NS, HL_FREE, row, 0, 4)
      vim.api.nvim_buf_add_highlight(buf, NS, HL_KEY, row, 4, e.label_end)
      vim.api.nvim_buf_add_highlight(buf, NS, HL_DIM, row, e.label_end, -1)
    end
  end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Public API
-- ─────────────────────────────────────────────────────────────────────────────

--- Open the interactive capability browser for a specific LSP client.
---
--- Browser key bindings:
---   <CR>       assign a keymap to the capability on the current line
---   f          toggle "hide already-mapped capabilities"
---   d          toggle the Discovered Capabilities section
---   q / <Esc>  close
---
--- @param client  vim.lsp.Client
--- @param bufnr   integer
--- @param opts    table
function M.open(client, bufnr, opts)
  setup_highlights()

  local active_keys = caps.get_active(client)
  local discovered = caps.discover_unknown(client)
  local show_mapped = true -- toggled by `f`
  local show_discovered = true -- toggled by `d`

  -- ── build_display ──────────────────────────────────────────────────────────
  local function build_display()
    local lines = {}
    local entries = {}
    local existing = M.get_existing_map(bufnr, active_keys)

    -- Header bar
    table.insert(
      lines,
      string.format(
        '  Client: %s  |  known: %d  |  discovered: %d' .. '  |  [f] mapped  [d] discovered  [<CR>] map  [q] close',
        client.name,
        #active_keys,
        #discovered
      )
    )
    table.insert(entries, { row = 0, is_header = true })

    table.insert(lines, string.rep('-', 80))
    table.insert(entries, { row = 1, is_header = true })

    -- Section 1 – known registry capabilities
    table.insert(lines, '  [1] Known Capabilities')
    table.insert(entries, { row = #lines - 1, is_header = true })

    local visible = 0
    for _, cap_key in ipairs(active_keys) do
      local def = caps.registry[cap_key]
      local mapped = existing[cap_key]

      if show_mapped or not mapped then
        local icon = mapped and '* ' or 'o '
        local hint = mapped and string.format('  [bound: %s]', mapped.lhs) or string.format('  [suggested: %s]', def.suggested)
        local label = def.label
        local line = string.format('  %s%-30s  %-38s%s', icon, label, def.description, hint)
        local lbl_end = 4 + #label

        table.insert(lines, line)
        table.insert(entries, {
          row = #lines - 1,
          cap_key = cap_key,
          def = def,
          is_header = false,
          is_mapped = mapped ~= nil,
          is_discovered = false,
          label_end = lbl_end,
        })
        visible = visible + 1
      end
    end

    if visible == 0 then
      table.insert(lines, '    (all known capabilities are already mapped - press f to show)')
      table.insert(entries, { row = #lines - 1, is_header = true })
    end

    -- Blank separator
    table.insert(lines, '')
    table.insert(entries, { row = #lines - 1, is_header = true })

    -- Section 2 – dynamically discovered capabilities
    if show_discovered then
      table.insert(
        lines,
        string.format('  [2] Discovered Capabilities (%d)' .. '  - scanned from server_capabilities at runtime  [d to collapse]', #discovered)
      )
      table.insert(entries, { row = #lines - 1, is_header = true })

      if #discovered == 0 then
        table.insert(lines, '    (none - server only advertises standard LSP capabilities)')
        table.insert(entries, { row = #lines - 1, is_header = true })
      else
        table.insert(lines, '    + = auto-handler available   ! = informational only')
        table.insert(entries, { row = #lines - 1, is_header = true })

        for _, disc in ipairs(discovered) do
          local icon = disc.fn and '+ ' or '! '
          local label = disc.label
          local line = string.format('  %s%-30s  %-38s  key: %-35s val: %s', icon, label, disc.description, disc.cap_key, disc.value_summary)
          local lbl_end = 4 + #label

          table.insert(lines, line)
          table.insert(entries, {
            row = #lines - 1,
            cap_key = disc.cap_key,
            def = disc,
            is_header = false,
            is_mapped = false,
            is_discovered = true,
            has_handler = disc.fn ~= nil,
            label_end = lbl_end,
          })
        end
      end
    else
      table.insert(lines, string.format('  [2] Discovered Capabilities (%d)  [press d to expand]', #discovered))
      table.insert(entries, { row = #lines - 1, is_header = true })
    end

    return lines, entries
  end

  -- Initial render
  local lines, entry_meta = build_display()
  local fbuf, fwin = open_float(TITLE, lines)
  apply_highlights(fbuf, entry_meta)

  -- Shared refresh
  local function refresh()
    lines, entry_meta = build_display()
    vim.api.nvim_set_option_value('modifiable', true, { buf = fbuf })
    local safe = {}
    for _, l in ipairs(lines) do
      table.insert(safe, sanitize_line(l))
    end
    vim.api.nvim_buf_set_lines(fbuf, 0, -1, false, safe)
    vim.api.nvim_set_option_value('modifiable', false, { buf = fbuf })
    vim.api.nvim_buf_clear_namespace(fbuf, NS, 0, -1)
    apply_highlights(fbuf, entry_meta)
  end

  local function current_entry()
    local row = vim.api.nvim_win_get_cursor(fwin)[1] - 1
    for _, e in ipairs(entry_meta) do
      if e.row == row and not e.is_header and e.cap_key then
        return e
      end
    end
    return nil
  end

  -- ── Key bindings ───────────────────────────────────────────────────────────
  local mo = { buffer = fbuf, nowait = true, silent = true }

  nvim_utils.bind_close_keys(fbuf, fwin, { 'q', '<Esc>' }, mo)

  nvim_utils.buf_map(fbuf, 'n', 'f', function()
    show_mapped = not show_mapped
    refresh()
  end, mo)

  nvim_utils.buf_map(fbuf, 'n', 'd', function()
    show_discovered = not show_discovered
    refresh()
  end, mo)

  nvim_utils.buf_map(fbuf, 'n', '<CR>', function()
    local entry = current_entry()
    if not entry then
      return
    end

    -- Discovered caps with no auto-handler cannot be mapped
    if entry.is_discovered and not entry.has_handler then
      vim.notify(
        string.format(
          "[lsp-keymapper] '%s' has no automatic handler.\n" .. 'It is an informational capability only (raw key: %s).',
          entry.def.label,
          entry.cap_key
        ),
        vim.log.levels.WARN
      )
      return
    end

    local def = entry.def
    nvim_utils.close_win(fwin, true)

    vim.schedule(function()
      M.prompt_and_bind(client, bufnr, entry.cap_key, def, opts, function()
        M.open(client, bufnr, opts)
      end)
    end)
  end, mo)
end

--- Prompt for a key sequence and register the binding.
---
--- @param client   vim.lsp.Client
--- @param bufnr    integer
--- @param cap_key  string
--- @param def      table   LspCapabilityDef or DiscoveredCapability
--- @param opts     table
--- @param on_done  function|nil
function M.prompt_and_bind(client, bufnr, cap_key, def, opts, on_done)
  local prompt = string.format("[lsp-keymapper] Bind '%s' - enter key (e.g. <leader>gd), blank to skip: ", def.label)

  vim.ui.input({ prompt = prompt, default = def.suggested or '' }, function(input)
    if not input or input == '' then
      vim.notify('[lsp-keymapper] Skipped.', vim.log.levels.INFO)
      if on_done then
        on_done()
      end
      return
    end

    for _, mode in ipairs(def.modes) do
      local conflict = keymaps.find_conflict(input, mode, bufnr)
      if conflict then
        vim.notify(string.format("[lsp-keymapper] Warning: '%s' (%s) already mapped -> %s", input, mode, keymaps.describe(conflict)), vim.log.levels.WARN)
      end
    end

    keymaps.set(bufnr, def.modes, input, def.fn, def.label)

    if opts.persist then
      opts._store.save(client.name, cap_key, input)
    end

    vim.notify(string.format("[lsp-keymapper] Bound '%s' -> %s", input, def.label), vim.log.levels.INFO)

    if on_done then
      on_done()
    end
  end)
end

--- Return a table of cap_key -> existing keymap entry for already-mapped caps.
---
--- @param bufnr     integer
--- @param cap_keys  string[]
--- @return table<string, vim.api.keyset.get_keymap>
function M.get_existing_map(bufnr, cap_keys)
  local all_maps = keymaps.get_buf_keymaps(bufnr, { 'n', 'v', 'i' })
  local result = {}

  for _, cap_key in ipairs(cap_keys) do
    local def = caps.registry[cap_key]
    for _, mode in ipairs(def.modes) do
      local lookup = mode .. def.suggested
      if all_maps[lookup] then
        result[cap_key] = all_maps[lookup]
        break
      end
    end
  end

  return result
end

return M
