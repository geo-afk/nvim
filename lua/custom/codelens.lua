local M = {}

local state = {
  augroup = nil,
  settings = {
    codelens = false,
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
  enabled_buffers = {},
}

local METHODS = vim.lsp.protocol.Methods or {}
local METHOD_CODELENS = METHODS.textDocument_codeLens or "textDocument/codeLens"
local METHOD_REFERENCES = METHODS.textDocument_references or "textDocument/references"

local function buf_enabled(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local enabled = state.enabled_buffers[bufnr]
  if enabled == nil then
    return state.settings.codelens == true
  end
  return enabled
end

local function supports_method(bufnr, method)
  return #vim.lsp.get_clients({ bufnr = bufnr, method = method }) > 0
end

local function normalize_qf_item(item)
  return {
    filename = item.filename or item.bufnr and vim.api.nvim_buf_get_name(item.bufnr) or "",
    bufnr = item.bufnr,
    lnum = item.lnum,
    col = item.col,
    text = item.text or "",
  }
end

local function sync_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) or vim.bo[bufnr].buftype ~= "" then
    return
  end
  if not supports_method(bufnr, METHOD_CODELENS) then
    return
  end

  vim.lsp.codelens.enable(buf_enabled(bufnr), { bufnr = bufnr })
end

local function setup_autocmds()
  if state.augroup then
    return
  end

  state.augroup = vim.api.nvim_create_augroup("CustomCodeLens", { clear = true })

  vim.api.nvim_create_autocmd("LspAttach", {
    group = state.augroup,
    callback = function(args)
      vim.schedule(function()
        sync_buffer(args.buf)
      end)
    end,
  })

  vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold", "InsertLeave" }, {
    group = state.augroup,
    callback = function(args)
      if buf_enabled(args.buf) then
        sync_buffer(args.buf)
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

local function get_lens_entries(bufnr)
  return vim.lsp.codelens.get({ bufnr = bufnr }) or {}
end

local function find_nearest_lens(entries, target_line)
  local closest
  local min_distance = math.huge

  for _, entry in ipairs(entries) do
    local lens = entry.lens
    local distance = math.abs(lens.range.start.line - target_line)
    if distance < min_distance then
      min_distance = distance
      closest = entry
    end
  end

  return closest
end

local function jump_to_item(item, command)
  command = command or "edit"
  if not item then
    return
  end

  local filename = item.filename
  if (not filename or filename == "") and item.bufnr and vim.api.nvim_buf_is_valid(item.bufnr) then
    filename = vim.api.nvim_buf_get_name(item.bufnr)
  end
  if not filename or filename == "" then
    return
  end

  vim.cmd(command .. " " .. vim.fn.fnameescape(filename))
  vim.api.nvim_win_set_cursor(0, { item.lnum, math.max((item.col or 1) - 1, 0) })
  vim.cmd("normal! zz")
end

local function open_references_fallback(items, symbol)
  local title = ("References: %s"):format(symbol ~= "" and symbol or "symbol")
  vim.fn.setqflist({}, " ", {
    title = title,
    items = items,
  })
  vim.cmd("botright copen")
end

local function open_references_picker(items, symbol)
  if not state.settings.reference_ui.use_telescope then
    open_references_fallback(items, symbol)
    return
  end

  local ok_pickers, pickers = pcall(require, "telescope.pickers")
  local ok_finders, finders = pcall(require, "telescope.finders")
  local ok_conf, conf = pcall(require, "telescope.config")
  local ok_entry, make_entry = pcall(require, "telescope.make_entry")
  local ok_previewers, previewers = pcall(require, "telescope.previewers")
  local ok_actions, actions = pcall(require, "telescope.actions")
  local ok_state, action_state = pcall(require, "telescope.actions.state")
  local ok_themes, themes = pcall(require, "telescope.themes")

  if not (ok_pickers and ok_finders and ok_conf and ok_entry and ok_previewers and ok_actions and ok_state and ok_themes) then
    open_references_fallback(items, symbol)
    return
  end

  local opts = themes.get_dropdown({
    previewer = true,
    border = true,
    layout_strategy = "horizontal",
    layout_config = {
      width = 0.92,
      height = 0.84,
      preview_width = 0.58,
    },
    prompt_title = ("References · %s"):format(symbol ~= "" and symbol or "symbol"),
    results_title = ("%d matches"):format(#items),
    prompt_prefix = "  ",
    selection_caret = "  ",
    path_display = { "truncate" },
  })

  pickers
    .new(opts, {
      finder = finders.new_table({
        results = items,
        entry_maker = make_entry.gen_from_quickfix(opts),
      }),
      previewer = previewers.qflist.new(opts),
      sorter = conf.values.generic_sorter(opts),
      attach_mappings = function(prompt_bufnr)
        local function select(command)
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          jump_to_item(selection, command)
        end

        actions.select_default:replace(function()
          select("edit")
        end)

        local map = function(lhs, command)
          vim.keymap.set("i", lhs, function()
            select(command)
          end, { buffer = prompt_bufnr, silent = true })
          vim.keymap.set("n", lhs, function()
            select(command)
          end, { buffer = prompt_bufnr, silent = true })
        end

        map("<C-s>", "split")
        map("<C-v>", "vsplit")
        return true
      end,
    })
    :find()
end

local function collect_reference_items(bufnr, callback)
  local params = vim.lsp.util.make_position_params(0)
  params.context = {
    includeDeclaration = state.settings.reference_ui.include_declaration == true,
  }

  vim.lsp.buf_request_all(bufnr, METHOD_REFERENCES, params, function(results)
    local seen = {}
    local items = {}

    for client_id, response in pairs(results or {}) do
      local result = response and response.result or nil
      if result and not vim.tbl_isempty(result) then
        local client = vim.lsp.get_client_by_id(client_id)
        local encoding = client and client.offset_encoding or "utf-16"
        local qf_items = vim.lsp.util.locations_to_items(result, encoding)

        for _, item in ipairs(qf_items) do
          local normalized = normalize_qf_item(item)
          local key = table.concat({
            normalized.filename,
            normalized.lnum or 0,
            normalized.col or 0,
            normalized.text,
          }, ":")

          if not seen[key] then
            seen[key] = true
            items[#items + 1] = normalized
          end
        end
      end
    end

    table.sort(items, function(a, b)
      if a.filename == b.filename then
        if a.lnum == b.lnum then
          return (a.col or 0) < (b.col or 0)
        end
        return (a.lnum or 0) < (b.lnum or 0)
      end
      return (a.filename or "") < (b.filename or "")
    end)

    callback(items)
  end)
end

local function handle_double_click()
  if not buf_enabled(0) then
    vim.api.nvim_input("<2-LeftMouse>")
    return
  end

  M.run_action()
end

function M.is_enabled(bufnr)
  return buf_enabled(bufnr)
end

function M.get_keymaps()
  return vim.deepcopy(state.settings.keymaps or {})
end

function M.set_enabled(enabled, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  state.enabled_buffers[bufnr] = enabled == true
  sync_buffer(bufnr)
end

function M.toggle(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local enabled = not vim.lsp.codelens.is_enabled({ bufnr = bufnr })
  state.enabled_buffers[bufnr] = enabled
  sync_buffer(bufnr)

  vim.notify(
    enabled and "CodeLens enabled for this buffer" or "CodeLens disabled for this buffer",
    vim.log.levels.INFO,
    { title = "CodeLens" }
  )
end

function M.attach(bufnr, client)
  if client and client:supports_method(METHOD_CODELENS, { bufnr = bufnr }) then
    sync_buffer(bufnr)
  end
end

function M.refresh_all()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buftype == "" and buf_enabled(bufnr) then
      sync_buffer(bufnr)
    end
  end
end

function M.clear_all()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.lsp.codelens.enable(false, { bufnr = bufnr })
    end
  end
end

function M.run_action()
  local bufnr = vim.api.nvim_get_current_buf()
  if not buf_enabled(bufnr) then
    vim.notify("CodeLens is disabled for this buffer", vim.log.levels.WARN, { title = "CodeLens" })
    return
  end

  local current_line = vim.api.nvim_win_get_cursor(0)[1] - 1
  local entries = get_lens_entries(bufnr)

  if #entries == 0 then
    vim.notify("No CodeLens found in this buffer", vim.log.levels.INFO, { title = "CodeLens" })
    return
  end

  for _, entry in ipairs(entries) do
    if entry.lens.range.start.line == current_line then
      vim.lsp.codelens.run({ client_id = entry.client_id })
      return
    end
  end

  local nearest = find_nearest_lens(entries, current_line)
  if not nearest then
    vim.notify("No CodeLens on the current line", vim.log.levels.INFO, { title = "CodeLens" })
    return
  end

  local lens = nearest.lens
  vim.api.nvim_win_set_cursor(0, {
    lens.range.start.line + 1,
    lens.range.start.character,
  })
  vim.lsp.codelens.run({ client_id = nearest.client_id })
end

function M.show_references()
  local bufnr = vim.api.nvim_get_current_buf()
  if not supports_method(bufnr, METHOD_REFERENCES) then
    vim.notify("No LSP client in this buffer supports references", vim.log.levels.WARN, { title = "References" })
    return
  end

  local symbol = vim.fn.expand("<cword>")
  collect_reference_items(bufnr, function(items)
    if #items == 0 then
      vim.notify("No references found for the symbol under cursor", vim.log.levels.INFO, { title = "References" })
      return
    end

    open_references_picker(items, symbol)
  end)
end

function M.setup(settings)
  state.settings = vim.tbl_deep_extend("force", state.settings, settings or {})
  setup_autocmds()

  vim.keymap.set("n", "<2-LeftMouse>", handle_double_click, {
    noremap = true,
    silent = true,
    desc = "Run CodeLens on double-click",
  })

  vim.api.nvim_create_user_command("LspCodeLensRun", function()
    M.run_action()
  end, {
    desc = "Run CodeLens action on current or nearest line",
  })

  vim.api.nvim_create_user_command("LspCodeLensToggle", function()
    M.toggle()
  end, {
    desc = "Toggle CodeLens for the current buffer",
  })

  vim.api.nvim_create_user_command("LspReferencesUI", function()
    M.show_references()
  end, {
    desc = "Show references for the symbol under cursor",
  })

  return M
end

return M
