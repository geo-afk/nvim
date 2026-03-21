-- codelens.lua
local M = {}

-- Module-level state
local state = {
  original_functions = {},
  autocmd_group = nil,
  settings = {},
}

-- Initialize module
local function init()
  -- Store original functions
  state.original_functions = {
    display = vim.lsp.codelens.display,
    refresh = vim.lsp.codelens.refresh,
    clear = vim.lsp.codelens.clear,
  }
end

-- Check if CodeLens is enabled based on settings
local function is_enabled()
  return state.settings.codelens or false
end

-- Clear all CodeLens namespaces across buffers
local function clear_all_namespaces()
  for name, ns_id in pairs(vim.api.nvim_get_namespaces()) do
    if type(name) == "string" and name:lower():find("codelens") then
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) then
          vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)
        end
      end
    end
  end
  vim.cmd("redraw!")
end

-- Setup autocmds for automatic CodeLens refresh
local function setup_autocmds()
  local group = vim.api.nvim_create_augroup("AutoCodeLens", { clear = true })

  vim.api.nvim_create_autocmd({ "LspAttach", "TextChanged", "TextChangedI" }, {
    callback = function()
      vim.defer_fn(function()
        if is_enabled() then
          vim.lsp.codelens.refresh()
        end
      end, 100)
    end,
    group = group,
  })

  return group
end

-- Enable CodeLens functionality
local function enable_codelens()
  -- Restore original functions
  vim.lsp.codelens.display = state.original_functions.display
  vim.lsp.codelens.refresh = state.original_functions.refresh
  vim.lsp.codelens.clear = state.original_functions.clear

  -- Schedule an initial refresh
  vim.schedule(function()
    vim.lsp.codelens.refresh()
  end)

  -- Setup autocmds if not already done
  if not state.autocmd_group then
    state.autocmd_group = setup_autocmds()
  end
end

-- Disable CodeLens functionality
local function disable_codelens()
  -- Override functions with no-ops
  vim.lsp.codelens.display = function() end
  vim.lsp.codelens.refresh = function() end
  vim.lsp.codelens.clear = function() end

  -- Clear all existing CodeLens
  clear_all_namespaces()

  -- Clear autocmds if they exist
  if state.autocmd_group then
    pcall(vim.api.nvim_clear_autocmds, { group = state.autocmd_group })
    state.autocmd_group = nil
  end
end

-- Find the nearest lens to a given line number
local function find_nearest_lens(lenses, target_line)
  local closest_lens = nil
  local min_distance = math.huge

  for _, lens in ipairs(lenses) do
    local distance = math.abs(lens.range.start.line - target_line)
    if distance < min_distance then
      min_distance = distance
      closest_lens = lens
    end
  end

  return closest_lens
end

-- Run CodeLens action for current line or nearest lens
local function run_codelens_action()
  if not is_enabled() then
    vim.notify("CodeLens is disabled", vim.log.levels.WARN)
    return
  end

  local current_pos = vim.api.nvim_win_get_cursor(0)
  local current_line = current_pos[1] - 1
  local lenses = vim.lsp.codelens.get(0) or {}

  -- Check if there's a lens on current line
  for _, lens in ipairs(lenses) do
    if lens.range.start.line == current_line then
      vim.lsp.codelens.run()
      return
    end
  end

  -- If no lens on current line, try to find nearest
  local nearest_lens = find_nearest_lens(lenses, current_line)
  if nearest_lens then
    vim.api.nvim_win_set_cursor(0, {
      nearest_lens.range.start.line + 1,
      nearest_lens.range.start.character,
    })
    vim.lsp.codelens.run()
    return
  end

  -- No lenses found
  if #lenses == 0 then
    vim.notify("No CodeLens found in this buffer", vim.log.levels.WARN)
  else
    vim.notify("No CodeLens on current line", vim.log.levels.INFO)
  end
end

-- Handle double-click mouse event
local function handle_double_click()
  if not is_enabled() then
    vim.api.nvim_input("<2-LeftMouse>")
    return
  end

  local current_pos = vim.api.nvim_win_get_cursor(0)
  local current_line = current_pos[1] - 1
  local lenses = vim.lsp.codelens.get(0) or {}

  for _, lens in ipairs(lenses) do
    if lens.range.start.line == current_line then
      vim.lsp.codelens.run()
      return
    end
  end

  vim.api.nvim_input("<2-LeftMouse>")
end

-- Public API

-- Set CodeLens enabled state
function M.set_enabled(enabled)
  if enabled then
    enable_codelens()
  else
    disable_codelens()
  end

  -- Update settings
  state.settings.codelens = enabled
end

-- Refresh all CodeLens
function M.refresh_all()
  if is_enabled() then
    vim.lsp.codelens.refresh()

    -- Trigger BufEnter for all normal buffers
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == "" then
        vim.cmd("doautocmd BufEnter")
      end
    end

    vim.cmd("redraw!")
  end
end

-- Clear all CodeLens
function M.clear_all()
  clear_all_namespaces()
end

-- Run CodeLens action (public wrapper)
function M.run_action()
  run_codelens_action()
end

-- Initialize module with settings
function M.setup(settings)
  -- Merge settings
  state.settings = vim.tbl_deep_extend("force", state.settings, settings or {})

  -- Initialize with original functions
  init()

  -- Apply initial enabled state
  if is_enabled() then
    enable_codelens()
  else
    disable_codelens()
  end

  -- Setup keymaps
  vim.keymap.set("n", "<2-LeftMouse>", handle_double_click, {
    noremap = true,
    silent = true,
    desc = "Run CodeLens on double-click",
  })

  -- Setup user commands
  vim.api.nvim_create_user_command("LspCodeLensRun", function()
    run_codelens_action()
  end, {
    desc = "Run CodeLens action on current or nearest line",
  })

  return M
end

return M
