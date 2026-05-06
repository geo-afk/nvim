-- debugger_virt.lua — inline variable values as extmarks in source buffers
local M = {}

local NS = vim.api.nvim_create_namespace("go_dbg_virt")
local prev_vals = {} -- { [name] = value } for change detection
local VIRT_POS = vim.fn.has("nvim-0.10") == 1 and "inline" or "eol"

local function norm(p)
  return vim.fn.fnamemodify(p, ":p"):gsub("\\", "/")
end

local function find_var_row(lines, name)
  local pat = "%f[%w_]" .. vim.pesc(name) .. "%f[^%w_]"
  for i, line in ipairs(lines) do
    if line:find(pat) then
      return i - 1
    end
  end
  return nil
end

local function buf_for(file)
  local fn = norm(file)
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(b) and norm(vim.api.nvim_buf_get_name(b)) == fn then
      return b
    end
  end
  return nil
end

function M.apply(file, vars)
  local bufnr = buf_for(file)
  if not bufnr then
    return
  end

  vim.api.nvim_buf_clear_namespace(bufnr, NS, 0, -1)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  for _, v in ipairs(vars) do
    local name = tostring(v.name or "")
    if name == "" then
      goto continue
    end
    local val = tostring(v.value or "")
    if #val > 40 then
      val = val:sub(1, 38) .. "…"
    end

    local row = find_var_row(lines, name)
    if row then
      local changed = prev_vals[name] ~= nil and prev_vals[name] ~= val
      local hl = changed and "DiagnosticVirtualTextWarn" or "DiagnosticVirtualTextInfo"
      pcall(vim.api.nvim_buf_set_extmark, bufnr, NS, row, 0, {
        virt_text = { { "  " .. name .. " = " .. val, hl } },
        virt_text_pos = VIRT_POS,
        priority = 90,
      })
      prev_vals[name] = val
    end
    ::continue::
  end
end

function M.clear(file)
  if not file then
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(b) then
        vim.api.nvim_buf_clear_namespace(b, NS, 0, -1)
      end
    end
    prev_vals = {}
    return
  end
  local bufnr = buf_for(file)
  if bufnr then
    vim.api.nvim_buf_clear_namespace(bufnr, NS, 0, -1)
  end
end

return M
