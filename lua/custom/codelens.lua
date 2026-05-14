local M = {}

-- ── Configuration & State ───────────────────────────────────────────────────

local state = {
  ns = vim.api.nvim_create_namespace("CustomCodeLens"),
  augroup = nil,
  refresh_timers = {}, -- bufnr -> timer
  enabled_buffers = {},
  config = {
    enabled = true,
    -- Rendering mode: "virt_text" (inline) or "virt_lines" (VSCode style)
    mode = "virt_lines",
    -- Only show lenses for the current function/block under cursor
    focused_only = false,
    -- Spacing between multiple lenses on the same line
    spacing = 2,
    -- Vertical offset for virt_lines (0 = directly above, -1 = further above)
    virt_lines_above = true,
    icons = {
      run = "󰐋 ",
      references = "󰄪 ",
      implementations = "󰆼 ",
      test = "󰙨 ",
      benchmark = "󰓅 ",
      generate = "󰚗 ",
      tidy = "󰗊 ",
      upgrade = "󰚰 ",
      default = "󰌶 ",
    },
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

local METHODS = vim.lsp.protocol.Methods or {}
local METHOD_CODELENS = METHODS.textDocument_codeLens or "textDocument/codeLens"
local METHOD_REFERENCES = METHODS.textDocument_references or "textDocument/references"

-- ── Utilities ───────────────────────────────────────────────────────────────

local function is_buf_valid(bufnr)
  return bufnr and vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buftype == ""
end

local function buf_enabled(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local enabled = state.enabled_buffers[bufnr]
  if enabled == nil then
    return state.config.enabled
  end
  return enabled
end

local function supports_codelens(bufnr)
  return #vim.lsp.get_clients({ bufnr = bufnr, method = METHOD_CODELENS }) > 0
end

local function get_icon(title)
  local t = title:lower()
  if t:find("run") or t:find("debug") then
    if t:find("test") then return state.config.icons.test end
    if t:find("benchmark") then return state.config.icons.benchmark end
    return state.config.icons.run
  elseif t:find("reference") then
    return state.config.icons.references
  elseif t:find("implementation") then
    return state.config.icons.implementations
  elseif t:find("test") then
    return state.config.icons.test
  elseif t:find("benchmark") then
    return state.config.icons.benchmark
  elseif t:find("generate") then
    return state.config.icons.generate
  elseif t:find("tidy") then
    return state.config.icons.tidy
  elseif t:find("upgrade") then
    return state.config.icons.upgrade
  end
  return state.config.icons.default
end

-- ── Rendering ───────────────────────────────────────────────────────────────

---Clear all lenses in a buffer.
function M.clear(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if is_buf_valid(bufnr) then
    vim.api.nvim_buf_clear_namespace(bufnr, state.ns, 0, -1)
  end
end

---Render lenses for a buffer based on current LSP cache.
function M.render(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not is_buf_valid(bufnr) or not buf_enabled(bufnr) then
    M.clear(bufnr)
    return
  end

  local lenses = vim.lsp.codelens.get({ bufnr = bufnr })
  M.clear(bufnr)

  if not lenses or #lenses == 0 then
    return
  end

  -- Group lenses by line
  local grouped = {}
  for _, entry in ipairs(lenses) do
    local lens = entry.lens
    if lens and lens.range then
      local line = lens.range.start.line
      grouped[line] = grouped[line] or {}
      table.insert(grouped[line], entry)
    end
  end

  local cursor_line = vim.api.nvim_win_get_cursor(0)[1] - 1

  for line, entries in pairs(grouped) do
    if not state.config.focused_only or math.abs(line - cursor_line) < 2 then
      local chunks = {}
      for i, entry in ipairs(entries) do
        local lens = entry.lens
        local title = (lens.command and lens.command.title) or "Unknown"
        local icon = get_icon(title)

        if i > 1 then
          table.insert(chunks, { string.rep(" ", state.config.spacing), "None" })
        end

        table.insert(chunks, { icon, state.config.highlights.icon })
        table.insert(chunks, { title, state.config.highlights.lens })
      end

      if state.config.mode == "virt_lines" then
        vim.api.nvim_buf_set_extmark(bufnr, state.ns, line, 0, {
          virt_lines = { chunks },
          virt_lines_above = state.config.virt_lines_above,
          hl_mode = "combine",
        })
      else
        vim.api.nvim_buf_set_extmark(bufnr, state.ns, line, 0, {
          virt_text = chunks,
          virt_text_pos = "eol",
          hl_mode = "combine",
        })
      end
    end
  end
end

-- ── Refresh Logic ───────────────────────────────────────────────────────────

---Request a codelens refresh from the server.
---@param bufnr integer
function M.refresh(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not is_buf_valid(bufnr) or not buf_enabled(bufnr) or not supports_codelens(bufnr) then
    return
  end

  -- In Neovim 0.10+, vim.lsp.codelens.enable(true) is the standard way.
  -- To force a refresh (similar to go.nvim), we disable and re-enable.
  vim.lsp.codelens.enable(false, { bufnr = bufnr })
  vim.lsp.codelens.enable(true, { bufnr = bufnr })
end

---Debounced refresh and render.
function M.schedule_refresh(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not is_buf_valid(bufnr) then return end

  if state.refresh_timers[bufnr] then
    state.refresh_timers[bufnr]:stop()
  else
    state.refresh_timers[bufnr] = vim.uv.new_timer()
  end

  state.refresh_timers[bufnr]:start(500, 0, vim.schedule_wrap(function()
    M.refresh(bufnr)
  end))
end

-- ── Autocmds ────────────────────────────────────────────────────────────────

local function setup_autocmds()
  if state.augroup then
    return
  end

  state.augroup = vim.api.nvim_create_augroup("CustomCodeLens", { clear = true })

  vim.api.nvim_create_autocmd({ "LspAttach", "BufEnter", "InsertLeave", "BufWritePre", "BufWritePost" }, {
    group = state.augroup,
    callback = function(args)
      if buf_enabled(args.buf) then
        M.schedule_refresh(args.buf)
      end
    end,
  })

  -- Refresh rendering on cursor move if focused_only is enabled
  vim.api.nvim_create_autocmd("CursorMoved", {
    group = state.augroup,
    callback = function(args)
      if state.config.focused_only and buf_enabled(args.buf) then
        M.render(args.buf)
      end
    end,
  })

  vim.api.nvim_create_autocmd("BufWipeout", {
    group = state.augroup,
    callback = function(args)
      state.enabled_buffers[args.buf] = nil
      if state.refresh_timers[args.buf] then
        state.refresh_timers[args.buf]:stop()
        if not state.refresh_timers[args.buf]:is_closing() then
          state.refresh_timers[args.buf]:close()
        end
        state.refresh_timers[args.buf] = nil
      end
    end,
  })

  -- Override the default display handler to use our custom rendering
  -- This ensures that whenever the LSP returns results, we render them our way.
  local old_on_codelens = vim.lsp.handlers[METHOD_CODELENS]
  vim.lsp.handlers[METHOD_CODELENS] = function(err, result, ctx, config)
    if old_on_codelens then
      old_on_codelens(err, result, ctx, config)
    else
      vim.lsp.codelens.on_codelens(err, result, ctx, config)
    end
    M.render(ctx.bufnr)
  end
end

-- ── Public API ───────────────────────────────────────────────────────────────

function M.run_action()
  local bufnr = vim.api.nvim_get_current_buf()
  if not buf_enabled(bufnr) then
    vim.notify("CodeLens is disabled for this buffer", vim.log.levels.WARN, { title = "CodeLens" })
    return
  end

  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local cursor_line = cursor_pos[1] - 1
  local lenses = vim.lsp.codelens.get({ bufnr = bufnr })

  if not lenses or #lenses == 0 then
    vim.notify("No CodeLens found", vim.log.levels.INFO, { title = "CodeLens" })
    return
  end

  -- 1. Find all lenses on the current line
  local line_lenses = {}
  for _, entry in ipairs(lenses) do
    if entry.lens.range.start.line == cursor_line then
      table.insert(line_lenses, entry)
    end
  end

  local target = nil
  if #line_lenses > 0 then
    -- Already on the right line, snap to the first lens's character
    target = line_lenses[1]
  else
    -- 2. Find nearest if none on current line (handles clicking virt_lines above/below)
    local min_dist = math.huge
    for _, entry in ipairs(lenses) do
      local dist = math.abs(entry.lens.range.start.line - cursor_line)
      if dist < min_dist then
        min_dist = dist
        target = entry
      end
    end
    -- Only snap if it's reasonably close (e.g., within 2 lines)
    if not target or math.abs(target.lens.range.start.line - cursor_line) > 2 then
      vim.notify("No CodeLens nearby", vim.log.levels.INFO, { title = "CodeLens" })
      return
    end
  end

  if target then
    -- Move cursor to the exact start of the lens for reliable execution
    vim.api.nvim_win_set_cursor(0, { target.lens.range.start.line + 1, target.lens.range.start.character })
    
    -- Small defer to let the cursor move register before LSP request
    vim.schedule(function()
      vim.lsp.codelens.run()
    end)
  end
end

function M.toggle(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local enabled = not buf_enabled(bufnr)
  state.enabled_buffers[bufnr] = enabled

  -- Use enable() to toggle the built-in LSP codelens logic for this buffer.
  -- In 0.10+, this is the standard way to manage codelens lifecycle.
  vim.lsp.codelens.enable(enabled, { bufnr = bufnr })

  if not enabled then
    M.clear(bufnr)
  end

  vim.notify(
    enabled and "CodeLens enabled" or "CodeLens disabled",
    vim.log.levels.INFO,
    { title = "CodeLens" }
  )
end

function M.show_references()
  local bufnr = vim.api.nvim_get_current_buf()
  local symbol = vim.fn.expand("<cword>")
  
  local params = vim.lsp.util.make_position_params(0, "utf-8")
  params.context = {
    includeDeclaration = state.config.reference_ui.include_declaration == true,
  }

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
  
  -- Ensure highlights exist
  local hl = state.config.highlights
  vim.api.nvim_set_hl(0, hl.lens, { link = "Comment", default = true })
  vim.api.nvim_set_hl(0, hl.icon, { link = "Special", default = true })
  vim.api.nvim_set_hl(0, hl.separator, { link = "Comment", default = true })
  vim.api.nvim_set_hl(0, hl.text, { link = "Comment", default = true })
  vim.api.nvim_set_hl(0, hl.sign, { link = "Comment", default = true })

  setup_autocmds()

  -- User commands
  vim.api.nvim_create_user_command("LspCodeLensRun", M.run_action, { desc = "Run CodeLens action" })
  vim.api.nvim_create_user_command("LspCodeLensToggle", function() M.toggle() end, { desc = "Toggle CodeLens" })
  vim.api.nvim_create_user_command("LspReferencesUI", M.show_references, { desc = "Show references UI" })

  -- Default keymaps
  local km = state.config.keymaps
  vim.keymap.set("n", km.run, M.run_action, { desc = "LSP: Run CodeLens" })
  vim.keymap.set("n", km.toggle, function() M.toggle() end, { desc = "LSP: Toggle CodeLens" })
  vim.keymap.set("n", km.references, M.show_references, { desc = "LSP: Show References" })

  return M
end

return M
