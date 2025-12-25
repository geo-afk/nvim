local M = {}

-- Store progress messages per client
local progress_messages = {}

-- Handle LSP progress notifications
vim.api.nvim_create_autocmd('LspProgress', {
  group = vim.api.nvim_create_augroup('UserLspProgress', { clear = true }),
  callback = function(ev)
    -- Get client by ID
    local client_id = ev.data.client_id
    local client = vim.lsp.get_client_by_id(client_id)
    if not client then
      return
    end

    -- Access the correct data structure: ev.data.params
    local params = ev.data.params
    if not params then
      return
    end

    local token = params.token
    local value = params.value

    -- Ensure value exists before processing
    if not value then
      return
    end

    -- Initialize client progress storage
    progress_messages[client.name] = progress_messages[client.name] or {}

    -- Handle different kinds of progress messages
    if value.kind == 'begin' then
      progress_messages[client.name][token] = {
        title = value.title or 'Working',
        message = value.message or '',
        percentage = value.percentage or 0,
      }
    elseif value.kind == 'report' then
      -- Only update if the token exists
      if progress_messages[client.name][token] then
        progress_messages[client.name][token].message = value.message or progress_messages[client.name][token].message
        progress_messages[client.name][token].percentage = value.percentage or progress_messages[client.name][token].percentage
      end
    elseif value.kind == 'end' then
      -- Remove the progress message when done
      progress_messages[client.name][token] = nil

      -- Clean up empty client tables
      if vim.tbl_isempty(progress_messages[client.name]) then
        progress_messages[client.name] = nil
      end
    end
  end,
})

-- Get formatted LSP progress string
function M.get_progress()
  local parts = {}

  for client_name, msgs in pairs(progress_messages) do
    for _, msg in pairs(msgs) do
      local title = msg.title or ''
      local message = msg.message or ''
      local percentage = msg.percentage and string.format(' (%d%%)', msg.percentage) or ''

      -- Build the display string
      local display = client_name .. ': ' .. title
      if message ~= '' then
        display = display .. ' - ' .. message
      end
      display = display .. percentage

      table.insert(parts, display)
    end
  end

  return #parts > 0 and table.concat(parts, ' | ') or ''
end

-- Optional: Get progress for a specific client
function M.get_client_progress(client_name)
  if not progress_messages[client_name] then
    return ''
  end

  local parts = {}
  for _, msg in pairs(progress_messages[client_name]) do
    local title = msg.title or ''
    local message = msg.message or ''
    local percentage = msg.percentage and string.format(' (%d%%)', msg.percentage) or ''

    local display = title
    if message ~= '' then
      display = display .. ' - ' .. message
    end
    display = display .. percentage

    table.insert(parts, display)
  end

  return #parts > 0 and table.concat(parts, ' | ') or ''
end

-- Optional: Check if any LSP is currently working
function M.is_busy()
  return not vim.tbl_isempty(progress_messages)
end

return M
