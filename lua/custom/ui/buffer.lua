local nvim_utils = require("utils.nvim")

local M = {}

local function valid(buf)
  return type(buf) == "number" and vim.api.nvim_buf_is_valid(buf)
end

local function set_option(buf, name, value)
  if valid(buf) then
    pcall(vim.api.nvim_set_option_value, name, value, { buf = buf })
  end
end

function M.is_valid(buf)
  return valid(buf)
end

function M.create_raw(listed, scratch)
  return vim.api.nvim_create_buf(listed, scratch)
end

function M.create(opts)
  opts = opts or {}
  local buf = vim.api.nvim_create_buf(opts.listed == true, opts.scratch ~= false)

  if opts.name then
    pcall(vim.api.nvim_buf_set_name, buf, opts.name)
  end

  local options = vim.tbl_extend("force", {
    buftype = opts.buftype or "nofile",
    bufhidden = opts.bufhidden or "wipe",
    swapfile = false,
  }, opts.options or {})

  if opts.filetype then
    options.filetype = opts.filetype
  end
  if opts.modifiable ~= nil then
    options.modifiable = opts.modifiable
  end

  for name, value in pairs(options) do
    set_option(buf, name, value)
  end

  if opts.disable_completion ~= false then
    M.disable_completion(buf)
  end

  if opts.lines then
    M.set_lines(buf, opts.lines, { force_modifiable = true, modifiable = opts.modifiable })
  end

  return buf
end

function M.disable_completion(buf)
  if not valid(buf) then
    return
  end
  pcall(vim.api.nvim_buf_set_var, buf, "cmp_enabled", false)
  pcall(vim.api.nvim_buf_set_var, buf, "completion_enabled", false)
  pcall(vim.api.nvim_buf_set_var, buf, "completion", false)
  pcall(vim.api.nvim_buf_set_var, buf, "blink_cmp_enabled", false)
  pcall(vim.api.nvim_set_option_value, "completefunc", "", { buf = buf })
  pcall(vim.api.nvim_set_option_value, "omnifunc", "", { buf = buf })
end

function M.set_option(buf, name, value)
  set_option(buf, name, value)
end

function M.set_options(buf, options)
  for name, value in pairs(options or {}) do
    set_option(buf, name, value)
  end
end

function M.set_lines(buf, lines, opts)
  if not valid(buf) then
    return
  end

  opts = opts or {}
  local restore
  if opts.force_modifiable then
    local ok, current = pcall(vim.api.nvim_get_option_value, "modifiable", { buf = buf })
    restore = ok and current or nil
    set_option(buf, "modifiable", true)
  end

  pcall(vim.api.nvim_buf_set_lines, buf, opts.start or 0, opts.finish or -1, opts.strict or false, lines or {})

  if opts.modifiable ~= nil then
    set_option(buf, "modifiable", opts.modifiable)
  elseif restore ~= nil then
    set_option(buf, "modifiable", restore)
  end
end

function M.update_lines(buf, lines)
  if not valid(buf) then
    return
  end

  lines = lines or {}
  local current = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local prefix = 0
  local max_prefix = math.min(#current, #lines)
  while prefix < max_prefix and current[prefix + 1] == lines[prefix + 1] do
    prefix = prefix + 1
  end

  local suffix = 0
  local max_suffix = math.min(#current - prefix, #lines - prefix)
  while suffix < max_suffix and current[#current - suffix] == lines[#lines - suffix] do
    suffix = suffix + 1
  end

  if prefix == #current and prefix == #lines then
    return
  end

  local replacement = {}
  for i = prefix + 1, #lines - suffix do
    replacement[#replacement + 1] = lines[i]
  end

  local ok, modifiable = pcall(vim.api.nvim_get_option_value, "modifiable", { buf = buf })
  if ok and not modifiable then
    set_option(buf, "modifiable", true)
  end
  pcall(vim.api.nvim_buf_set_lines, buf, prefix, #current - suffix, false, replacement)
  if ok and not modifiable then
    set_option(buf, "modifiable", false)
  end
end

function M.delete(buf, opts)
  if valid(buf) then
    pcall(vim.api.nvim_buf_delete, buf, opts or { force = true })
  end
end

function M.map(buf, mode, lhs, rhs, opts)
  return nvim_utils.buf_map(buf, mode, lhs, rhs, opts)
end

return M
