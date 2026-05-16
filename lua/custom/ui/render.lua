local M = {}

local namespaces = {}

function M.ns(name)
  name = name or "custom_ui"
  if not namespaces[name] then
    namespaces[name] = vim.api.nvim_create_namespace(name)
  end
  return namespaces[name]
end

function M.clear(buf, ns, start, finish)
  if vim.api.nvim_buf_is_valid(buf) then
    pcall(vim.api.nvim_buf_clear_namespace, buf, ns, start or 0, finish or -1)
  end
end

function M.set_extmark(buf, ns, row, col, opts)
  if not vim.api.nvim_buf_is_valid(buf) then
    return nil
  end
  local ok, id = pcall(vim.api.nvim_buf_set_extmark, buf, ns, row, col, opts or {})
  return ok and id or nil
end

function M.highlight(buf, ns, group, row, start_col, end_col, opts)
  opts = vim.tbl_extend("force", { hl_group = group }, opts or {})
  if end_col and end_col >= 0 then
    opts.end_col = end_col
  elseif end_col == -1 then
    opts.hl_eol = true
  end
  return M.set_extmark(buf, ns, row, start_col or 0, opts)
end

function M.add_highlight(buf, ns, group, row, start_col, end_col)
  return M.highlight(buf, ns, group, row, start_col, end_col)
end

function M.virtual_text(buf, ns, row, col, virt_text, opts)
  opts = vim.tbl_extend("force", {
    virt_text = virt_text,
    virt_text_pos = "eol",
  }, opts or {})
  return M.set_extmark(buf, ns, row, col or 0, opts)
end

function M.apply(buf, ns, items, clear)
  if clear ~= false then
    M.clear(buf, ns, 0, -1)
  end
  for _, item in ipairs(items or {}) do
    if item.virt_text then
      M.virtual_text(buf, ns, item.row or item.lnum or 0, item.col or 0, item.virt_text, item)
    else
      M.highlight(
        buf,
        ns,
        item.group or item.hl_group,
        item.row or item.lnum or 0,
        item.col_start or item.col or 0,
        item.col_end or item.end_col,
        item
      )
    end
  end
end

return M
