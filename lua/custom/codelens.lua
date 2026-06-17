local M = {}

-- ── Configuration & State ───────────────────────────────────────────────────

local state = {
  ns = vim.api.nvim_create_namespace("CustomCodeLens"),
  augroup = nil,
  enabled_buffers = {},
  attached_buffers = {},
  cache = {},
  timers = {},
  setup_done = false,
  config = {
    enabled = true,
    mode = "virt_text",
    focused_only = false,
    spacing = 2,
    virt_lines_above = true,
    align = "range",
    debounce_ms = 500,
    max_inline_width = 80,
    mouse = true,
    clickable = true,
    icons = {
      run = "󰐋 ",
      debug = "󰃤 ",
      references = "󰄪 ",
      implementations = "󰆼 ",
      test = "󰙨 ",
      benchmark = "󰓅 ",
      generate = "󰚗 ",
      tidy = "󰗊 ",
      upgrade = "󰚰 ",
      default = "󰌶 ",
    },
    icon_map = {},
    highlights = {
      lens = "LspCodeLens",
      icon = "LspCodeLensIcon",
      separator = "LspCodeLensSeparator",
      text = "LspCodeLensText",
      sign = "LspCodeLensSign",
    },
    keymaps = {
      run = "<leader>cc",
      toggle = "<leader>cC",
      references = "<leader>cR",
    },
    reference_ui = {
      include_declaration = false,
      use_telescope = true,
    },
  },
}

local uv = vim.uv or vim.loop
local METHODS = vim.lsp.protocol.Methods or {}
local METHOD_CODELENS = METHODS.textDocument_codeLens or "textDocument/codeLens"
local METHOD_CODELENS_RESOLVE = METHODS.codeLens_resolve or "codeLens/resolve"
local METHOD_CODELENS_REFRESH = METHODS.workspace_codeLens_refresh or "workspace/codeLens/refresh"
local METHOD_REFERENCES = METHODS.textDocument_references or "textDocument/references"

-- ── Utilities ───────────────────────────────────────────────────────────────

local function resolve_bufnr(bufnr)
  if not bufnr or bufnr == 0 then
    return vim.api.nvim_get_current_buf()
  end
  return bufnr
end

local function is_buf_valid(bufnr)
  bufnr = resolve_bufnr(bufnr)
  return bufnr and vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buftype == ""
end

local function changedtick(bufnr)
  return vim.api.nvim_buf_get_changedtick(bufnr)
end

local function buf_enabled(bufnr)
  bufnr = resolve_bufnr(bufnr)
  local enabled = state.enabled_buffers[bufnr]
  if enabled == nil then
    return state.config.enabled
  end
  return enabled
end

local function supports_method(client, method, bufnr)
  if not client then
    return false
  end
  local ok, supported = pcall(client.supports_method, client, method, bufnr)
  return ok and supported == true
end

local function get_clients(bufnr, method)
  local clients = vim.lsp.get_clients({ bufnr = bufnr, method = method })
  if #clients > 0 then
    return clients
  end

  clients = vim.lsp.get_clients({ bufnr = bufnr })
  return vim.tbl_filter(function(client)
    return supports_method(client, method, bufnr)
  end, clients)
end

local function supports_codelens(bufnr)
  return #get_clients(bufnr, METHOD_CODELENS) > 0
end

local function supports_codelens_resolve(client, bufnr)
  if supports_method(client, METHOD_CODELENS_RESOLVE, bufnr) then
    return true
  end
  local provider = client and client.server_capabilities and client.server_capabilities.codeLensProvider
  return type(provider) == "table" and provider.resolveProvider == true
end

local function ensure_cache(bufnr)
  bufnr = resolve_bufnr(bufnr)
  local cache = state.cache[bufnr]
  if not cache then
    cache = {
      seq = 0,
      tick = 0,
      by_client = {},
      lenses = {},
      extmarks = {},
      last_render_key = "",
      request_pending = false,
      refresh_timer = nil,
    }
    state.cache[bufnr] = cache
  end
  return cache
end

local function lens_title(lens)
  return lens and lens.command and lens.command.title or "Resolving..."
end

local function lens_kind(title, command)
  local haystack = ((title or "") .. " " .. (command or "")):lower()
  for kind in pairs(state.config.icons) do
    if kind ~= "default" and haystack:find(kind, 1, true) then
      return kind
    end
  end
  if haystack:find("ref", 1, true) then
    return "references"
  end
  if haystack:find("impl", 1, true) then
    return "implementations"
  end
  return "default"
end

local function get_icon(lens)
  local title = lens_title(lens)
  local command = lens and lens.command and lens.command.command or ""

  for pattern, icon in pairs(state.config.icon_map or {}) do
    if title:lower():find(pattern:lower(), 1, true) or command:lower():find(pattern:lower(), 1, true) then
      return icon
    end
  end

  return state.config.icons[lens_kind(title, command)] or state.config.icons.default
end

local function normalize_lenses(result, client_id, filter_unresolved)
  local lenses = {}
  for _, item in ipairs(result or {}) do
    local lens = item.lens or item
    -- Skip lenses that failed resolution or are invalid
    local valid = lens and not lens.__invalid and lens.range and lens.range.start and type(lens.range.start.line) == "number"
    if valid then
      -- If filter_unresolved is true, only include lenses with a command (e.g. during initial refresh)
      -- This hides "Resolving..." initially but keeps them stable during typing.
      if not filter_unresolved or lens.command then
        table.insert(lenses, {
          client_id = item.client_id or client_id,
          lens = lens,
        })
      end
    end
  end
  return lenses
end

local function rebuild_cache(bufnr, filter_unresolved)
  local cache = ensure_cache(bufnr)
  local lenses = {}
  for client_id, client_lenses in pairs(cache.by_client) do
    vim.list_extend(lenses, normalize_lenses(client_lenses, client_id, filter_unresolved))
  end
  table.sort(lenses, function(a, b)
    local ar = a.lens.range.start
    local br = b.lens.range.start
    if ar.line == br.line then
      return ar.character < br.character
    end
    return ar.line < br.line
  end)
  cache.lenses = lenses
end

local function lens_col(bufnr, lens, client)
  local ok, range = pcall(vim.range.lsp, bufnr, lens.range, client and client.offset_encoding or "utf-16")
  if ok and range and range.start_col then
    return math.max(range.start_col, 0)
  end
  return math.max(lens.range.start.character or 0, 0)
end

local function line_is_valid(bufnr, line)
  return line >= 0 and line < vim.api.nvim_buf_line_count(bufnr)
end

local function resolve_lens(bufnr, item, callback)
  local lens = item and item.lens
  local client = item and vim.lsp.get_client_by_id(item.client_id)
  if not lens or not client then
    callback(nil, nil)
    return
  end

  if lens.command then
    callback(client, lens)
    return
  end

  if not supports_codelens_resolve(client, bufnr) then
    callback(client, nil)
    return
  end

  local tick = changedtick(bufnr)
  local timer = uv.new_timer()
  local done = false

  local function finish(c, l)
    if done then return end
    done = true
    if timer then
      if timer:is_active() then timer:stop() end
      if not timer:is_closing() then timer:close() end
    end
    callback(c, l)
  end

  timer:start(5000, 0, vim.schedule_wrap(function()
    finish(client, nil)
  end))

  client:request(METHOD_CODELENS_RESOLVE, lens, function(err, resolved)
    if not is_buf_valid(bufnr) or changedtick(bufnr) ~= tick then
      finish(client, nil)
      return
    end

    if err or not resolved then
      finish(client, nil)
      return
    end

    item.lens = resolved
    local cache = ensure_cache(bufnr)
    local client_lenses = cache.by_client[item.client_id]
    if client_lenses then
      for i, cached in ipairs(client_lenses) do
        local l_ref = cached.lens or cached
        if l_ref == lens then
          client_lenses[i] = resolved
          break
        end
      end
    end
    rebuild_cache(bufnr)
    M.render(bufnr)
    finish(client, resolved)
  end, bufnr)
end

local function execute_lens(bufnr, item)
  resolve_lens(bufnr, item, function(client, lens)
    if not client or not lens or not lens.command then
      vim.notify("CodeLens is not executable yet", vim.log.levels.INFO, { title = "CodeLens" })
      return
    end
    client:exec_cmd(lens.command, { bufnr = bufnr })
    vim.defer_fn(function()
      if is_buf_valid(bufnr) and buf_enabled(bufnr) then
        M.refresh(bufnr)
      end
    end, 80)
  end)
end

local function items_on_or_near_line(bufnr, line, max_distance)
  local cache = ensure_cache(bufnr)
  local exact = {}
  local nearby = {}
  local best_distance = max_distance + 1

  for _, item in ipairs(cache.lenses or {}) do
    local lens_line = item.lens.range.start.line
    if lens_line == line then
      table.insert(exact, item)
    else
      local distance = math.abs(lens_line - line)
      if distance <= max_distance then
        if distance < best_distance then
          nearby = {}
          best_distance = distance
        end
        if distance == best_distance then
          table.insert(nearby, item)
        end
      end
    end
  end

  if #exact > 0 then
    return exact
  end
  return nearby
end

local function render_key(bufnr, grouped)
  local parts = { tostring(vim.o.columns), state.config.mode, tostring(state.config.focused_only) }
  for line, entries in pairs(grouped) do
    local titles = {}
    for _, item in ipairs(entries) do
      table.insert(titles, item.client_id .. ":" .. lens_title(item.lens))
    end
    table.sort(titles)
    table.insert(parts, line .. "=" .. table.concat(titles, ","))
  end
  table.sort(parts)
  return table.concat(parts, "|")
end

local function mouse_lens_line(bufnr, pos)
  if not pos or pos.winid == 0 or not state.cache[bufnr] then
    return nil
  end

  for _, item in ipairs(state.cache[bufnr].lenses or {}) do
    local line = item.lens.range.start.line
    local screen = vim.fn.screenpos(pos.winid, line + 1, 1)
    if screen and screen.row and screen.row > 0 then
      if state.config.mode == "virt_lines" then
        local lens_row = screen.row + (state.config.virt_lines_above and -1 or 1)
        if pos.screenrow == lens_row then
          return line
        end
      elseif pos.line == line + 1 then
        local text = vim.api.nvim_buf_get_lines(bufnr, line, line + 1, false)[1] or ""
        if pos.screencol > screen.col + vim.fn.strdisplaywidth(text) then
          return line
        end
      end
    end
  end

  return nil
end

local function set_mouse_keymap(bufnr)
  if not state.config.mouse then
    return
  end

  vim.keymap.set("n", "<LeftMouse>", function()
    local pos = vim.fn.getmousepos()
    local line = mouse_lens_line(bufnr, pos)
    if line and M.run_action({ bufnr = bufnr, line = line, mouse = true, silent = true }) then
      return
    end

    local keys = vim.api.nvim_replace_termcodes("<LeftMouse>", true, false, true)
    vim.api.nvim_feedkeys(keys, "n", false)
  end, { buffer = bufnr, silent = true, desc = "CodeLens mouse" })
end

-- ── Rendering ───────────────────────────────────────────────────────────────

function M.clear(bufnr)
  bufnr = resolve_bufnr(bufnr)
  if is_buf_valid(bufnr) then
    vim.api.nvim_buf_clear_namespace(bufnr, state.ns, 0, -1)
  end
  local cache = state.cache[bufnr]
  if cache then
    cache.extmarks = {}
    cache.last_render_key = ""
    cache.request_pending = false
    if cache.refresh_timer then
      if cache.refresh_timer:is_active() then cache.refresh_timer:stop() end
      if not cache.refresh_timer:is_closing() then cache.refresh_timer:close() end
      cache.refresh_timer = nil
    end
  end
end

function M.render(bufnr, lenses)
  bufnr = resolve_bufnr(bufnr)
  if not is_buf_valid(bufnr) or not buf_enabled(bufnr) then
    M.clear(bufnr)
    return
  end

  local cache = ensure_cache(bufnr)
  if lenses then
    cache.by_client[0] = vim.tbl_map(function(item)
      return item.lens or item
    end, normalize_lenses(lenses, 0))
    rebuild_cache(bufnr)
  end

  local grouped = {}
  for _, item in ipairs(cache.lenses or {}) do
    local lens = item.lens
    local line = lens.range.start.line
    if line_is_valid(bufnr, line) then
      grouped[line] = grouped[line] or {}
      table.insert(grouped[line], item)
    end
  end

  local cursor_line = vim.api.nvim_win_get_cursor(0)[1] - 1
  if state.config.focused_only then
    for line in pairs(grouped) do
      if math.abs(line - cursor_line) > 2 then
        grouped[line] = nil
      end
    end
  end

  local key = render_key(bufnr, grouped)
  if key == cache.last_render_key then
    return
  end
  cache.last_render_key = key

  local live = {}
  local win_width = math.max(vim.api.nvim_win_get_width(0) - 2, 20)
  local max_width = math.min(state.config.max_inline_width, win_width)

  for line, entries in pairs(grouped) do
    table.sort(entries, function(a, b)
      return (a.lens.range.start.character or 0) < (b.lens.range.start.character or 0)
    end)

    local client = vim.lsp.get_client_by_id(entries[1].client_id)
    local indent = state.config.align == "range" and lens_col(bufnr, entries[1].lens, client) or 0
    local chunks = {}
    if indent > 0 and state.config.mode == "virt_lines" then
      table.insert(chunks, { string.rep(" ", indent), "Normal" })
    end

    local used = indent
    for i, item in ipairs(entries) do
      local title = lens_title(item.lens)
      local icon = get_icon(item.lens)
      local text = title
      local reserve = vim.fn.strdisplaywidth(icon) + vim.fn.strdisplaywidth(text) + state.config.spacing
      if used + reserve > max_width then
        local available = math.max(max_width - used - vim.fn.strdisplaywidth(icon) - 1, 8)
        text = vim.fn.strcharpart(title, 0, available) .. "…"
      end

      if i > 1 then
        table.insert(chunks, { string.rep(" ", state.config.spacing), state.config.highlights.separator })
        used = used + state.config.spacing
      end

      table.insert(chunks, { icon, state.config.highlights.icon })
      table.insert(chunks, { text, state.config.highlights.lens })
      used = used + vim.fn.strdisplaywidth(icon) + vim.fn.strdisplaywidth(text)
    end

    local opts
    if state.config.mode == "virt_lines" then
      opts = {
        virt_lines = { chunks },
        virt_lines_above = state.config.virt_lines_above,
        virt_lines_overflow = "scroll",
        hl_mode = "combine",
        priority = 160,
        right_gravity = false,
      }
    else
      opts = {
        virt_text = chunks,
        virt_text_pos = "eol",
        virt_text_hide = true,
        hl_mode = "combine",
        priority = 160,
        right_gravity = false,
      }
    end

    if state.config.clickable then
      opts.url = "nvim-codelens://" .. bufnr .. "/" .. line
    end

    local mark = cache.extmarks[line]
    opts.id = mark
    live[line] = vim.api.nvim_buf_set_extmark(bufnr, state.ns, line, 0, opts)
  end

  for line, mark in pairs(cache.extmarks) do
    if not live[line] then
      pcall(vim.api.nvim_buf_del_extmark, bufnr, state.ns, mark)
    end
  end
  cache.extmarks = live
end

-- ── Refresh Logic ───────────────────────────────────────────────────────────

function M.refresh(bufnr)
  bufnr = resolve_bufnr(bufnr)
  if not is_buf_valid(bufnr) or not buf_enabled(bufnr) then
    return
  end

  local clients = get_clients(bufnr, METHOD_CODELENS)
  if #clients == 0 then
    M.clear(bufnr)
    return
  end

  local cache = ensure_cache(bufnr)
  
  -- Cleanup previous refresh timer
  if cache.refresh_timer then
    if cache.refresh_timer:is_active() then cache.refresh_timer:stop() end
    if not cache.refresh_timer:is_closing() then cache.refresh_timer:close() end
    cache.refresh_timer = nil
  end

  cache.seq = cache.seq + 1
  cache.tick = changedtick(bufnr)
  cache.request_pending = true
  
  local seq = cache.seq
  local tick = cache.tick
  local pending = #clients
  local params = { textDocument = vim.lsp.util.make_text_document_params(bufnr) }

  local function on_client_done()
    pending = pending - 1
    if pending <= 0 then
      if cache.refresh_timer then
        if cache.refresh_timer:is_active() then cache.refresh_timer:stop() end
        if not cache.refresh_timer:is_closing() then cache.refresh_timer:close() end
        cache.refresh_timer = nil
      end
      cache.request_pending = false
      if is_buf_valid(bufnr) and cache.seq == seq then
        rebuild_cache(bufnr, true)
        M.render(bufnr)
      end
    end
  end

  -- Global refresh timeout to prevent stuck "Resolving..." state
  cache.refresh_timer = uv.new_timer()
  cache.refresh_timer:start(5000, 0, vim.schedule_wrap(function()
    if cache.seq == seq and cache.request_pending then
      pending = 0
      on_client_done()
    end
  end))

  for _, client in ipairs(clients) do
    local ok = client:request(METHOD_CODELENS, params, function(err, result)
      if not is_buf_valid(bufnr) or cache.seq ~= seq then
        return
      end

      if changedtick(bufnr) ~= tick then
        on_client_done()
        M.debounce_refresh(bufnr, 40)
        return
      end

      if err or not result or #result == 0 then
        cache.by_client[client.id] = {}
        on_client_done()
        return
      end

      -- Proactive resolution for "Resolving..." lenses to fix UI blocking
      local to_resolve = {}
      if supports_codelens_resolve(client, bufnr) then
        for _, lens in ipairs(result) do
          if not lens.command then table.insert(to_resolve, lens) end
        end
      end

      if #to_resolve == 0 then
        cache.by_client[client.id] = result
        on_client_done()
      else
        local res_pending = #to_resolve
        local res_done = false
        local function on_resolve_done()
          if res_done then return end
          res_pending = res_pending - 1
          if res_pending <= 0 then
            res_done = true
            cache.by_client[client.id] = result
            on_client_done()
          end
        end

        -- Sub-timeout for proactive resolution
        vim.defer_fn(function()
          if cache.seq == seq and not res_done then
            res_pending = 0
            on_resolve_done()
          end
        end, 2000)

        for _, lens in ipairs(to_resolve) do
          client:request(METHOD_CODELENS_RESOLVE, lens, function(res_err, resolved)
            if not is_buf_valid(bufnr) or cache.seq ~= seq then
              on_resolve_done()
              return
            end
            if not res_err and resolved then
              for k, v in pairs(resolved) do lens[k] = v end
            else
              -- Mark as invalid so it's hidden from UI
              lens.__invalid = true
            end
            on_resolve_done()
          end, bufnr)
        end
      end
    end, bufnr)

    if not ok then
      cache.by_client[client.id] = {}
      on_client_done()
    end
  end

  -- Edge case: if no requests were actually sent
  if pending <= 0 then
    cache.request_pending = false
    rebuild_cache(bufnr)
    M.render(bufnr)
  end
end

function M.debounce_refresh(bufnr, delay)
  bufnr = resolve_bufnr(bufnr)
  if not is_buf_valid(bufnr) or not buf_enabled(bufnr) then
    return
  end

  local timer = state.timers[bufnr]
  if timer then
    if timer:is_active() then timer:stop() end
    if not timer:is_closing() then timer:close() end
  end

  state.timers[bufnr] = vim.defer_fn(function()
    state.timers[bufnr] = nil
    M.refresh(bufnr)
  end, delay or state.config.debounce_ms)
end

-- ── Setup & Handlers ────────────────────────────────────────────────────────

local function setup_handler()
  if state.setup_done then
    return
  end

  local previous_refresh = vim.lsp.handlers[METHOD_CODELENS_REFRESH]
  vim.lsp.handlers[METHOD_CODELENS_REFRESH] = function(err, result, ctx, config)
    if previous_refresh then
      pcall(previous_refresh, err, result, ctx, config)
    end
    if err then
      return vim.NIL
    end

    for bufnr in pairs(state.enabled_buffers) do
      if is_buf_valid(bufnr) then
        for _, client in ipairs(get_clients(bufnr, METHOD_CODELENS)) do
          if client.id == ctx.client_id then
            M.debounce_refresh(bufnr, 40)
            break
          end
        end
      end
    end
    return vim.NIL
  end

  state.setup_done = true
end

local function setup_autocmds()
  if state.augroup then
    return
  end

  state.augroup = vim.api.nvim_create_augroup("CustomCodeLens", { clear = true })

  vim.api.nvim_create_autocmd("BufEnter", {
    group = state.augroup,
    callback = function(args)
      if buf_enabled(args.buf) then
        M.render(args.buf)
        M.debounce_refresh(args.buf, 40)
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "InsertLeave", "BufWritePost" }, {
    group = state.augroup,
    callback = function(args)
      if buf_enabled(args.buf) and supports_codelens(args.buf) then
        M.debounce_refresh(args.buf, 1000)
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "CursorMoved", "WinResized" }, {
    group = state.augroup,
    callback = function(args)
      if buf_enabled(args.buf) then
        M.render(args.buf)
      end
    end,
  })

  vim.api.nvim_create_autocmd("LspDetach", {
    group = state.augroup,
    callback = function(args)
      local cache = state.cache[args.buf]
      if cache and args.data and args.data.client_id then
        cache.by_client[args.data.client_id] = nil
        rebuild_cache(args.buf)
      end

      if supports_codelens(args.buf) then
        M.render(args.buf)
        return
      end

      M.clear(args.buf)
      state.enabled_buffers[args.buf] = nil
      state.attached_buffers[args.buf] = nil
      state.cache[args.buf] = nil
    end,
  })

  vim.api.nvim_create_autocmd("BufWipeout", {
    group = state.augroup,
    callback = function(args)
      local timer = state.timers[args.buf]
      if timer then
        if timer:is_active() then timer:stop() end
        if not timer:is_closing() then timer:close() end
      end
      state.timers[args.buf] = nil
      state.enabled_buffers[args.buf] = nil
      state.attached_buffers[args.buf] = nil
      M.clear(args.buf)
      state.cache[args.buf] = nil
    end,
  })
end

-- ── Public API ───────────────────────────────────────────────────────────────

function M.on_attach(client, bufnr)
  if not supports_method(client, METHOD_CODELENS, bufnr) then
    return
  end

  state.enabled_buffers[bufnr] = true

  if not state.attached_buffers[bufnr] then
    state.attached_buffers[bufnr] = true
    local km = state.config.keymaps
    local opts = { buffer = bufnr, silent = true }

    vim.keymap.set("n", km.run, function()
      M.run_action({ bufnr = bufnr })
    end, vim.tbl_extend("force", opts, { desc = "LSP: Run CodeLens" }))
    vim.keymap.set("n", km.toggle, function()
      M.toggle(bufnr)
    end, vim.tbl_extend("force", opts, { desc = "LSP: Toggle CodeLens" }))
    vim.keymap.set("n", km.references, M.show_references, vim.tbl_extend("force", opts, { desc = "LSP: Show References" }))
    set_mouse_keymap(bufnr)
  end

  M.debounce_refresh(bufnr, 20)
end

function M.run_action(opts)
  opts = opts or {}
  local bufnr = resolve_bufnr(opts.bufnr)
  if not buf_enabled(bufnr) then
    if not opts.silent then
      vim.notify("CodeLens is disabled for this buffer", vim.log.levels.WARN, { title = "CodeLens" })
    end
    return false
  end

  local line = opts.line
  if not line then
    line = vim.api.nvim_win_get_cursor(0)[1] - 1
  end

  local candidates = items_on_or_near_line(bufnr, line, opts.mouse and 1 or 2)
  if #candidates == 0 then
    if ensure_cache(bufnr).request_pending then
      if not opts.silent then
        vim.notify("CodeLens is still refreshing", vim.log.levels.INFO, { title = "CodeLens" })
      end
      return false
    end
    if not opts.silent then
      vim.notify("No CodeLens found", vim.log.levels.INFO, { title = "CodeLens" })
    end
    return false
  end

  if #candidates == 1 then
    execute_lens(bufnr, candidates[1])
    return true
  end

  vim.ui.select(candidates, {
    prompt = "CodeLens",
    kind = "codelens",
    format_item = function(item)
      local client = vim.lsp.get_client_by_id(item.client_id)
      return string.format("%s %s [%s]", get_icon(item.lens), lens_title(item.lens), client and client.name or "LSP")
    end,
  }, function(item)
    if item then
      execute_lens(bufnr, item)
    end
  end)
  return true
end

function M.toggle(bufnr)
  bufnr = resolve_bufnr(bufnr)
  local enabled = not buf_enabled(bufnr)
  state.enabled_buffers[bufnr] = enabled

  if enabled then
    M.refresh(bufnr)
  else
    M.clear(bufnr)
  end

  vim.notify(enabled and "CodeLens enabled" or "CodeLens disabled", vim.log.levels.INFO, { title = "CodeLens" })
end

function M.show_references()
  local bufnr = vim.api.nvim_get_current_buf()
  local symbol = vim.fn.expand("<cword>")

  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  if not clients or #clients == 0 then
    return
  end

  local params = vim.tbl_extend("force", vim.lsp.util.make_position_params(0, clients[1].offset_encoding), {
    context = {
      includeDeclaration = state.config.reference_ui.include_declaration == true,
    },
  })

  vim.lsp.buf_request(bufnr, METHOD_REFERENCES, params, function(err, result, ctx)
    if err or not result or vim.tbl_isempty(result) then
      vim.notify("No references found", vim.log.levels.INFO, { title = "References" })
      return
    end

    local client = vim.lsp.get_client_by_id(ctx.client_id)
    local items = vim.lsp.util.locations_to_items(result, client and client.offset_encoding or "utf-16")

    if state.config.reference_ui.use_telescope then
      local ok, telescope = pcall(require, "telescope.builtin")
      if ok then
        telescope.lsp_references({
          include_declaration = state.config.reference_ui.include_declaration,
          initial_mode = "normal",
        })
        return
      end
    end

    vim.fn.setqflist({}, " ", { title = "References: " .. symbol, items = items })
    vim.cmd("botright copen")
  end)
end

function M.setup(user_config)
  state.config = vim.tbl_deep_extend("force", state.config, user_config or {})

  local hl = state.config.highlights
  vim.api.nvim_set_hl(0, hl.lens, { link = "Comment", default = true })
  vim.api.nvim_set_hl(0, hl.icon, { link = "Special", default = true })
  vim.api.nvim_set_hl(0, hl.separator, { link = "Comment", default = true })
  vim.api.nvim_set_hl(0, hl.text, { link = "Comment", default = true })
  vim.api.nvim_set_hl(0, hl.sign, { link = "Comment", default = true })

  setup_handler()
  setup_autocmds()

  vim.api.nvim_create_user_command("LspCodeLensRun", function()
    M.run_action()
  end, { desc = "Run CodeLens action", force = true })
  vim.api.nvim_create_user_command("LspCodeLensToggle", function()
    M.toggle()
  end, { desc = "Toggle CodeLens", force = true })
  vim.api.nvim_create_user_command("LspCodeLensRefresh", function()
    M.refresh()
  end, { desc = "Refresh CodeLens", force = true })
  vim.api.nvim_create_user_command("LspReferencesUI", M.show_references, { desc = "Show references UI", force = true })

  return M
end

return M
