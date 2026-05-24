local M = {}

-- ── Configuration & State ───────────────────────────────────────────────────

local state = {
  ns = vim.api.nvim_create_namespace("CustomCodeLens"),
  augroup = nil,
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
    if t:find("test") then
      return state.config.icons.test
    end
    if t:find("benchmark") then
      return state.config.icons.benchmark
    end
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

---Render lenses for a buffer based on current LSP cache or provided result.
---@param bufnr  integer?
---@param lenses table?   Optional raw LSP result
function M.render(bufnr, lenses)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not is_buf_valid(bufnr) or not buf_enabled(bufnr) then
    M.clear(bufnr)
    return
  end

  -- Use provided lenses or fetch from cache
  lenses = lenses or vim.lsp.codelens.get({ bufnr = bufnr })
  M.clear(bufnr)

  if not lenses or #lenses == 0 then
    return
  end

  -- Group lenses by line
  local grouped = {}
  for _, lens in ipairs(lenses) do
    if lens and lens.range then
      local line = lens.range.start.line
      grouped[line] = grouped[line] or {}
      table.insert(grouped[line], lens)
    end
  end

  local cursor_line = vim.api.nvim_win_get_cursor(0)[1] - 1

  for line, entries in pairs(grouped) do
    if not state.config.focused_only or math.abs(line - cursor_line) < 2 then
      local chunks = {}
      for i, lens in ipairs(entries) do
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

  -- The modern way to trigger a refresh in 0.12/0.13 is enable(true).
  -- Our custom handler will intercept the result and perform custom rendering.
  vim.lsp.codelens.enable(true, { bufnr = bufnr })
end

-- ── Setup & Handlers ────────────────────────────────────────────────────────

local function setup_handler()
  -- Intercept CodeLens results to prevent native rendering while allowing custom rendering.
  -- This override prevents Neovim from calling its internal on_codelens/display.
  vim.lsp.handlers[METHOD_CODELENS] = function(err, result, ctx, _)
    if err or not result then
      return
    end

    -- Manually update the buffer cache so codelens.run() can find the lenses.
    -- We use the buffer variable directly to avoid deprecated save() calls.
    vim.b[ctx.bufnr].lsp_code_lens = result

    if is_buf_valid(ctx.bufnr) and buf_enabled(ctx.bufnr) then
      M.render(ctx.bufnr, result)
    end
  end
end

local function setup_autocmds()
  if state.augroup then
    return
  end

  state.augroup = vim.api.nvim_create_augroup("CustomCodeLens", { clear = true })

  -- Initial render on Enter (using cached data)
  vim.api.nvim_create_autocmd("BufEnter", {
    group = state.augroup,
    callback = function(args)
      if buf_enabled(args.buf) then
        M.render(args.buf)
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
    end,
  })
end

-- ── Public API ───────────────────────────────────────────────────────────────

---Shared LspAttach handler to be called from config/lsp.lua.
---@param client table
---@param bufnr integer
function M.on_attach(client, bufnr)
  if not client.supports_method(METHOD_CODELENS) then
    return
  end

  -- Enable native codelens lifecycle (handles automatic refreshes on InsertLeave/BufWritePost).
  -- Our handler override ensures that ONLY our custom UI is displayed.
  vim.lsp.codelens.enable(true, { bufnr = bufnr })
  state.enabled_buffers[bufnr] = true

  -- Set up keymaps
  local km = state.config.keymaps
  local opts = { buffer = bufnr, silent = true }

  vim.keymap.set("n", km.run, M.run_action, vim.tbl_extend("force", opts, { desc = "LSP: Run CodeLens" }))
  vim.keymap.set("n", km.toggle, function()
    M.toggle(bufnr)
  end, vim.tbl_extend("force", opts, { desc = "LSP: Toggle CodeLens" }))
  vim.keymap.set("n", km.references, M.show_references, vim.tbl_extend("force", opts, { desc = "LSP: Show References" }))

  -- Initial refresh
  M.refresh(bufnr)
end

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
  for _, lens in ipairs(lenses) do
    if lens.range.start.line == cursor_line then
      table.insert(line_lenses, lens)
    end
  end

  local target = nil
  if #line_lenses > 0 then
    -- Already on the right line, snap to the first lens's character
    target = line_lenses[1]
  else
    -- 2. Find nearest if none on current line (handles clicking virt_lines above/below)
    local min_dist = math.huge
    for _, lens in ipairs(lenses) do
      local dist = math.abs(lens.range.start.line - cursor_line)
      if dist < min_dist then
        min_dist = dist
        target = lens
      end
    end
    -- Only snap if it's reasonably close (e.g., within 2 lines)
    if not target or math.abs(target.range.start.line - cursor_line) > 2 then
      vim.notify("No CodeLens nearby", vim.log.levels.INFO, { title = "CodeLens" })
      return
    end
  end

  if target then
    -- Move cursor to the exact start of the lens for reliable execution
    vim.api.nvim_win_set_cursor(0, { target.range.start.line + 1, target.range.start.character })

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
  vim.lsp.codelens.enable(enabled, { bufnr = bufnr })

  if not enabled then
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

  ---@diagnostic disable-next-line: inject-field
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

  -- Ensure highlights exist
  local hl = state.config.highlights
  vim.api.nvim_set_hl(0, hl.lens, { link = "Comment", default = true })
  vim.api.nvim_set_hl(0, hl.icon, { link = "Special", default = true })
  vim.api.nvim_set_hl(0, hl.separator, { link = "Comment", default = true })
  vim.api.nvim_set_hl(0, hl.text, { link = "Comment", default = true })
  vim.api.nvim_set_hl(0, hl.sign, { link = "Comment", default = true })

  setup_handler()
  setup_autocmds()

  -- Global user commands
  vim.api.nvim_create_user_command("LspCodeLensRun", M.run_action, { desc = "Run CodeLens action" })
  vim.api.nvim_create_user_command("LspCodeLensToggle", function()
    M.toggle()
  end, { desc = "Toggle CodeLens" })
  vim.api.nvim_create_user_command("LspReferencesUI", M.show_references, { desc = "Show references UI" })

  return M
end

return M
