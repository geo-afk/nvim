-- =============================================================================
-- lua/custom/lightbulb.lua
-- A lightweight, high-performance LSP code-action indicator.
-- =============================================================================

local M = {}

-- ── Internal State ───────────────────────────────────────────────────────────

local ns = vim.api.nvim_create_namespace("custom_lightbulb")
local state = {
  last_line = -1, -- Used to prevent redundant requests on the same line
}

-- ── Configuration ────────────────────────────────────────────────────────────

M.config = {
  ignore_ft = { "TelescopePrompt", "toggleterm", "lazy", "netrw", "help", "explorer" },
  sign = {
    enabled = true,
    text = "󰌵",
    hl = "DiagnosticSignInfo",
    priority = 10,
  },
  virtual_text = {
    enabled = false,
    text = "󰌵 Code Action",
    hl = "Comment",
  },
  float = {
    enabled = false, -- Display as a floating extmark (e.g., end of line)
    text = "󰌵",
    hl = "DiagnosticSignInfo",
  },
}

-- ── Helpers ──────────────────────────────────────────────────────────────────

--- Check if the current buffer is valid and not ignored
local function is_valid_buffer()
  local bufnr = vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end
  if vim.tbl_contains(M.config.ignore_ft, vim.bo[bufnr].filetype) then
    return false
  end
  local bt = vim.bo[bufnr].buftype
  return bt == "" or bt == "acwrite"
end

--- Clear the indicator from the current buffer
function M.clear()
  local bufnr = vim.api.nvim_get_current_buf()
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  end
end

--- The main rendering logic using Extmarks
--- @param bufnr number
--- @param line number (0-indexed)
local function render_indicator(bufnr, line)
  M.clear()

  local opts = {
    priority = M.config.sign.priority,
  }

  -- 1. Sign Column (Modern way: sign_text in extmark)
  if M.config.sign.enabled then
    opts.sign_text = M.config.sign.text
    opts.sign_hl_group = M.config.sign.hl
  end

  -- 2. Virtual Text
  if M.config.virtual_text.enabled then
    opts.virt_text = { { M.config.virtual_text.text, M.config.virtual_text.hl } }
    opts.virt_text_pos = "eol"
  end

  -- 3. Inline / Right-aligned Float (Extmark)
  if M.config.float.enabled then
    opts.virt_text = { { M.config.float.text, M.config.float.hl } }
    opts.virt_text_pos = "right_align"
  end

  pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, line, 0, opts)
end

-- ── Core Logic ───────────────────────────────────────────────────────────────

--- Send an async request to LSP servers to check for code actions
function M.refresh()
  if not is_valid_buffer() then
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1] - 1 -- convert to 0-indexed

  -- Performance optimization: Only check if we moved to a new line
  if line == state.last_line then
    return
  end
  state.last_line = line

  -- Check if any client supports code actions
  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  local target_client = nil
  for _, client in ipairs(clients) do
    if client:supports_method("textDocument/codeAction") then
      target_client = client
      break
    end
  end

  if not target_client then
    M.clear()
    return
  end

  -- Prepare LSP Parameters
  local params = vim.lsp.util.make_range_params(0, target_client.offset_encoding)
  -- Include diagnostics in context so servers can return specific fixes
  params.context = {
    diagnostics = vim.lsp.diagnostic.get_line_diagnostics(bufnr, line),
  }

  -- Send asynchronous request to all supporting clients
  vim.lsp.buf_request(bufnr, "textDocument/codeAction", params, function(err, result, _)
    -- If error or no actions, hide bulb
    if err or not result or vim.tbl_isempty(result) then
      M.clear()
      return
    end

    -- If the user moved lines while the async request was in flight, discard result
    if not vim.api.nvim_win_is_valid(0) then
      return
    end
    local current_cursor = vim.api.nvim_win_get_cursor(0)
    if (current_cursor[1] - 1) ~= line then
      return
    end

    -- Actions found! Render the indicator.
    render_indicator(bufnr, line)
  end)
end

-- ── Setup ────────────────────────────────────────────────────────────────────

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  local group = vim.api.nvim_create_augroup("CustomLightbulb", { clear = true })

  -- Request update when cursor stays still
  vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
    group = group,
    callback = M.refresh,
  })

  -- Clear immediately when moving to keep UI clean
  vim.api.nvim_create_autocmd({ "CursorMoved", "InsertEnter", "BufLeave" }, {
    group = group,
    callback = function()
      -- Reset line tracker on movement so we can re-trigger on the same line if needed
      local bufnr = vim.api.nvim_get_current_buf()
      if not vim.api.nvim_buf_is_valid(bufnr) then
        return
      end
      local cursor = pcall(vim.api.nvim_win_get_cursor, 0)
      if not cursor then
        return
      end
      local line = vim.api.nvim_win_get_cursor(0)[1] - 1
      if line ~= state.last_line then
        state.last_line = -1
        M.clear()
      end
    end,
  })
end

return M
