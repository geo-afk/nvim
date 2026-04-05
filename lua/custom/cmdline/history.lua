-- nvim-cmdline/history.lua
-- Thin wrapper around Vim's native command/search history.

local M = {}

local cursors = {}

function M.reset(hist_type)
  if type(hist_type) == "string" then
    cursors[hist_type] = 0
  end
end

function M.older(hist_type)
  if type(hist_type) ~= "string" then
    return nil
  end
  cursors[hist_type] = (cursors[hist_type] or 0) + 1

  local ok, entry = pcall(vim.fn.histget, hist_type, -cursors[hist_type])
  if not ok or type(entry) ~= "string" or entry == "" then
    cursors[hist_type] = cursors[hist_type] - 1
    return nil
  end
  return entry
end

function M.newer(hist_type)
  if type(hist_type) ~= "string" then
    return nil
  end
  local cursor = cursors[hist_type] or 0
  if cursor <= 0 then
    return nil
  end

  cursors[hist_type] = cursor - 1
  if cursors[hist_type] == 0 then
    return nil
  end

  local ok, entry = pcall(vim.fn.histget, hist_type, -cursors[hist_type])
  if not ok or type(entry) ~= "string" or entry == "" then
    return nil
  end
  return entry
end

function M.add(hist_type, entry)
  if type(hist_type) == "string" and type(entry) == "string" and entry ~= "" then
    pcall(vim.fn.histadd, hist_type, entry)
  end
end

return M
