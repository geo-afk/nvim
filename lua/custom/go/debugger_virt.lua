-- debugger_virt.lua — inline variable values as extmarks in source buffers
local M = {}

local NS = vim.api.nvim_create_namespace("go_dbg_virt")
local S = {
  enabled = true,
  prev_vals = {}, -- { [file] = { [name] = value } }
}

local function setup_hl()
  local function def(name, opts)
    opts.default = true
    vim.api.nvim_set_hl(0, name, opts)
  end
  def("GoDbgVirt", { link = "DiagnosticVirtualTextInfo", italic = true })
  def("GoDbgVirtChanged", { link = "DiagnosticVirtualTextWarn", bold = true, italic = true })
end

local function norm(p)
  return vim.fn.fnamemodify(p, ":p"):gsub("\\", "/")
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

local GO_KEYWORDS = {
  ["break"] = true,
  ["default"] = true,
  ["func"] = true,
  ["interface"] = true,
  ["select"] = true,
  ["case"] = true,
  ["defer"] = true,
  ["go"] = true,
  ["map"] = true,
  ["struct"] = true,
  ["chan"] = true,
  ["else"] = true,
  ["goto"] = true,
  ["package"] = true,
  ["switch"] = true,
  ["const"] = true,
  ["fallthrough"] = true,
  ["if"] = true,
  ["range"] = true,
  ["type"] = true,
  ["continue"] = true,
  ["for"] = true,
  ["import"] = true,
  ["return"] = true,
  ["var"] = true,
  ["nil"] = true,
  ["true"] = true,
  ["false"] = true,
}

local function find_var_rows(lines, vars)
  local results = {} -- { [name] = row_idx }
  local to_find = {}
  for _, v in ipairs(vars) do
    local name = tostring(v.name or "")
    if name ~= "" and not GO_KEYWORDS[name] and not name:match("^%[") then
      to_find[name] = true
    end
  end

  if not next(to_find) then
    return results
  end

  -- build patterns once
  local patterns = {}
  for name in pairs(to_find) do
    patterns[name] = {
      "%f[%w_]" .. vim.pesc(name) .. "%s*[:]?=",
      "%f[%w_]" .. vim.pesc(name) .. "%f[^%w_]",
    }
  end

  -- search backwards for latest assignment or usage
  for i = #lines, 1, -1 do
    local line = lines[i]
    for name in pairs(to_find) do
      local pats = patterns[name]
      if line:find(pats[1]) or line:find(pats[2]) then
        results[name] = i - 1
        to_find[name] = nil -- found it
      end
    end
    if not next(to_find) then
      break
    end
  end
  return results
end

function M.toggle()
  S.enabled = not S.enabled
  if not S.enabled then
    M.clear()
  end
end

function M.apply(file, vars)
  if not S.enabled then
    return
  end
  local bufnr = buf_for(file)
  if not bufnr then
    return
  end

  setup_hl()
  local fname = norm(file)
  S.prev_vals[fname] = S.prev_vals[fname] or {}
  local file_prev = S.prev_vals[fname]

  vim.api.nvim_buf_clear_namespace(bufnr, NS, 0, -1)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local var_rows = find_var_rows(lines, vars)

  for _, v in ipairs(vars) do
    local name = tostring(v.name or "")
    local row = var_rows[name]
    if row then
      local val = tostring(v.value or "")
      if #val > 50 then
        val = val:sub(1, 48) .. "…"
      end

      local changed = file_prev[name] ~= nil and file_prev[name] ~= val
      local hl = changed and "GoDbgVirtChanged" or "GoDbgVirt"

      pcall(require("custom.ui.render").set_extmark, bufnr, NS, row, 0, {
        virt_text = { { "  󱄑 " .. name .. " = " .. val, hl } },
        virt_text_pos = "eol",
        priority = 90,
      })
      file_prev[name] = val
    end
  end
end

function M.clear(file)
  if not file then
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(b) then
        vim.api.nvim_buf_clear_namespace(b, NS, 0, -1)
      end
    end
    S.prev_vals = {}
    return
  end
  local bufnr = buf_for(file)
  if bufnr then
    vim.api.nvim_buf_clear_namespace(bufnr, NS, 0, -1)
  end
end

return M
