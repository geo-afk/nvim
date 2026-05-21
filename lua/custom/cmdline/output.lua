-- nvim-cmdline/output.lua
-- Floating output viewer for command results such as :messages, :hi and :lua.

local M = {}

local _pkg = (...):match("^(.+)%.[^.]+$") or error("[nvim-cmdline] output.lua must be loaded as a submodule")

M.config = {
  min_width = 30,
  max_height_ratio = 0.60,
  default_wrap = false,
  enable_syntax = true,
}

M._last = nil

local function normalize_lines(lines)
  if type(lines) == "string" then
    lines = vim.split(lines, "\n", { plain = true })
  end
  if type(lines) ~= "table" then
    return {}
  end

  local normalized = {}
  for _, line in ipairs(lines) do
    normalized[#normalized + 1] = tostring(line or "")
  end

  while #normalized > 0 and normalized[#normalized]:match("^%s*$") do
    table.remove(normalized)
  end

  return normalized
end

local function truncate(text, max_len)
  if type(text) ~= "string" or text == "" then
    return ""
  end
  if #text <= max_len then
    return text
  end
  if max_len <= 1 then
    return text:sub(1, max_len)
  end
  return text:sub(1, max_len - 1) .. "…"
end

local function detect_format(command, is_error)
  local cmd = vim.trim(type(command) == "string" and command or "")
  local lower = cmd:lower()
  local format = {
    title = is_error and "Error" or "Output",
    kind = is_error and "error" or "output",
    filetype = "text",
    syntax = nil,
  }

  if lower == "" then
    return format
  end

  if lower:match("^messages!?$") or lower:match("^mes!?$") then
    format.title = "Messages"
    format.filetype = "vim"
    format.syntax = "vim"
    return format
  end

  if lower:match("^lua%s+") or lower:match("^lua%s*=%s*") or lower:match("^=%s*") then
    format.title = "Lua Output"
    format.filetype = "lua"
    format.syntax = "lua"
    return format
  end

  if lower:match("^%!") or lower:match("^read%s*!") or lower:match("^terminal") then
    format.title = "Shell Output"
    format.filetype = "sh"
    format.syntax = "sh"
    return format
  end

  if lower:match("^hi!?") or lower:match("^highlight!?") then
    format.title = "Highlights"
    format.filetype = "vim"
    format.syntax = "vim"
    return format
  end

  if
    lower:match("^set")
    or lower:match("^map")
    or lower:match("^command")
    or lower:match("^verbose")
    or lower:match("^autocmd")
    or lower:match("^augroup")
    or lower:match("^scriptnames")
  then
    format.title = "Editor Output"
    format.filetype = "vim"
    format.syntax = "vim"
    return format
  end

  if lower:match("^help%s+") or lower:match("^h%s+") then
    format.title = "Help Output"
    format.filetype = "help"
    format.syntax = "help"
    return format
  end

  return format
end

local function apply_highlighting(buf, format, enabled)
  vim.api.nvim_set_option_value("filetype", format.filetype, { buf = buf })
  if not enabled or not format.syntax then
    return
  end

  pcall(vim.api.nvim_set_option_value, "syntax", format.syntax, { buf = buf })

  if type(vim.treesitter) == "table" and type(vim.treesitter.start) == "function" then
    pcall(vim.treesitter.start, buf, format.syntax)
  end
end

local function set_viewer_buffer(buf, lines, format, syntax_enabled)
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
  vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
  vim.api.nvim_set_option_value("readonly", false, { buf = buf })
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
  vim.api.nvim_set_option_value("readonly", true, { buf = buf })
  apply_highlighting(buf, format, syntax_enabled)
end

local function create_buffer(lines, format, syntax_enabled)
  local buf = require("custom.ui.buffer").create_raw(false, true)
  set_viewer_buffer(buf, lines, format, syntax_enabled)
  return buf
end

local function make_title_chunks(format, command)
  local badge_hl = format.kind == "error" and "NvimCmdlineOutputTitleBadgeError" or "NvimCmdlineOutputTitleBadge"
  local text_hl = format.kind == "error" and "NvimCmdlineOutputTitleTextError" or "NvimCmdlineOutputTitleText"
  local cmd_hl = format.kind == "error" and "NvimCmdlineOutputTitleCmdError" or "NvimCmdlineOutputTitleCmd"
  local chunks = {
    { " " .. (format.kind == "error" and "ERR" or "OUT") .. " ", badge_hl },
    { " " .. format.title .. " ", text_hl },
  }

  local trimmed = vim.trim(type(command) == "string" and command or "")
  if trimmed ~= "" then
    chunks[#chunks + 1] = { " :" .. truncate(trimmed, 36) .. " ", cmd_hl }
  end

  return chunks
end

local function make_footer_chunks(lines, wrap_enabled, format)
  local accent = format.kind == "error" and "NvimCmdlineOutputHintKeyError" or "NvimCmdlineOutputHintKey"
  local chunks = {
    { " lines ", "NvimCmdlineOutputFooterLabel" },
    { (" %d "):format(#lines), "NvimCmdlineOutputFooterValue" },
    { "  ", "NvimCmdlineOutputFooterSep" },
    { " ft ", "NvimCmdlineOutputFooterLabel" },
    { " " .. format.filetype .. " ", "NvimCmdlineOutputFooterValue" },
    { "  ", "NvimCmdlineOutputFooterSep" },
    { " wrap ", "NvimCmdlineOutputFooterLabel" },
    { " " .. (wrap_enabled and "on" or "off") .. " ", accent },
    { "  ", "NvimCmdlineOutputFooterSep" },
    { " q ", accent },
    { " close ", "NvimCmdlineOutputFooterHint" },
    { "  ", "NvimCmdlineOutputFooterSep" },
    { " w ", accent },
    { " wrap ", "NvimCmdlineOutputFooterHint" },
    { "  ", "NvimCmdlineOutputFooterSep" },
    { " y ", accent },
    { " yank ", "NvimCmdlineOutputFooterHint" },
    { "  ", "NvimCmdlineOutputFooterSep" },
    { " s/v ", accent },
    { " split ", "NvimCmdlineOutputFooterHint" },
  }
  return chunks
end

local function update_chrome(win, lines, format, command)
  if not vim.api.nvim_win_is_valid(win) then
    return
  end

  local wrap_enabled = vim.api.nvim_get_option_value("wrap", { win = win })
  vim.api.nvim_win_set_config(win, {
    title = make_title_chunks(format, command),
    title_pos = "left",
    footer = make_footer_chunks(lines, wrap_enabled, format),
    footer_pos = "right",
  })
end

local function set_window_style(win, format, is_float)
  local normal = format.kind == "error" and "NvimCmdlineOutputErrorNormal" or "NvimCmdlineOutputNormal"
  local border = format.kind == "error" and "NvimCmdlineOutputErrorBorder" or "NvimCmdlineOutputBorder"

  local winhl = ("Normal:%s,EndOfBuffer:%s"):format(normal, normal)
  if is_float then
    winhl = winhl .. (",FloatBorder:%s"):format(border)
  end

  vim.api.nvim_set_option_value("winhighlight", winhl, { win = win })
  vim.api.nvim_set_option_value("wrap", M.config.default_wrap, { win = win })
  vim.api.nvim_set_option_value("linebreak", true, { win = win })
  vim.api.nvim_set_option_value("cursorline", true, { win = win })
  vim.api.nvim_set_option_value("scrolloff", 0, { win = win })
  vim.api.nvim_set_option_value("number", false, { win = win })
  vim.api.nvim_set_option_value("relativenumber", false, { win = win })
  vim.api.nvim_set_option_value("signcolumn", "no", { win = win })
  vim.api.nvim_set_option_value("foldenable", false, { win = win })
  vim.api.nvim_set_option_value("spell", false, { win = win })

  if not is_float and vim.fn.has("nvim-0.8") == 1 then
    local title = format.title:upper()
    local badge_hl = format.kind == "error" and "NvimCmdlineOutputTitleBadgeError" or "NvimCmdlineOutputTitleBadge"
    vim.api.nvim_set_option_value(
      "winbar",
      "%#WinSeparator# " .. "%#" .. badge_hl .. "# " .. title .. " %* ",
      { win = win }
    )
  end
end

local function apply_mappings(buf, win, lines, format, command, close_fn)
  local function buf_map(lhs, rhs)
    vim.keymap.set("n", lhs, rhs, { buffer = buf, noremap = true, silent = true, nowait = true })
  end

  buf_map("q", close_fn)
  buf_map("<Esc>", close_fn)

  buf_map("w", function()
    if not vim.api.nvim_win_is_valid(win) then
      return
    end
    local wrap = vim.api.nvim_get_option_value("wrap", { win = win })
    vim.api.nvim_set_option_value("wrap", not wrap, { win = win })
    if vim.api.nvim_win_get_config(win).relative ~= "" then
      update_chrome(win, lines, format, command)
    end
  end)

  buf_map("y", function()
    local text = table.concat(lines, "\n")
    vim.fn.setreg('"', text)
    pcall(vim.fn.setreg, "+", text)
    vim.notify("[nvim-cmdline] output copied", vim.log.levels.INFO)
  end)
end

local function open_split(kind, lines, format, command)
  local cmd = kind == "vsplit" and "botright vsplit" or "botright split"
  vim.cmd(cmd)
  local win = vim.api.nvim_get_current_win()
  local buf = create_buffer(lines, format, M.config.enable_syntax)
  vim.api.nvim_win_set_buf(win, buf)

  set_window_style(win, format, false)

  local function close()
    if vim.api.nvim_win_is_valid(win) then
      pcall(vim.api.nvim_win_close, win, true)
    end
  end

  apply_mappings(buf, win, lines, format, command, close)

  -- Specific split mappings: allow switching back to float or other split
  vim.keymap.set("n", "s", function()
    close()
    open_split("split", lines, format, command)
  end, { buffer = buf, noremap = true, silent = true })
  vim.keymap.set("n", "v", function()
    close()
    open_split("vsplit", lines, format, command)
  end, { buffer = buf, noremap = true, silent = true })

  pcall(vim.api.nvim_win_set_cursor, win, { 1, 0 })
end

local function store_last(spec)
  M._last = {
    lines = vim.deepcopy(spec.lines),
    is_error = spec.is_error == true,
    command = spec.command or "",
    border = spec.border,
    max_width = spec.max_width,
    target_row = spec.target_row,
  }
end

function M.show(spec)
  vim.validate("spec", spec, "table")

  local lines = normalize_lines(spec.lines)
  if #lines == 0 then
    return
  end

  local config = vim.tbl_deep_extend("force", M.config, spec.config or {})
  vim.validate(
    "min_width",
    config.min_width,
    "number",
    "max_height_ratio",
    config.max_height_ratio,
    "number",
    "default_wrap",
    config.default_wrap,
    "boolean",
    "enable_syntax",
    config.enable_syntax,
    "boolean"
  )

  local max_width = type(spec.max_width) == "number" and spec.max_width or math.floor(vim.o.columns * 0.6)
  local target_row = type(spec.target_row) == "number" and spec.target_row
    or math.max(0, vim.o.lines - vim.o.cmdheight - 3)
  local border = spec.border or "rounded"
  local format = detect_format(spec.command, spec.is_error == true)

  M.config = config
  store_last({
    lines = lines,
    is_error = spec.is_error,
    command = spec.command,
    border = border,
    max_width = max_width,
    target_row = target_row,
  })

  local longest = 0
  for _, line in ipairs(lines) do
    longest = math.max(longest, vim.fn.strdisplaywidth(line))
  end

  local width = math.min(max_width, math.max(config.min_width, longest + 2))
  local height = math.max(1, math.min(#lines, math.floor(vim.o.lines * config.max_height_ratio)))
  local row = math.max(0, target_row - height - 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local buf = create_buffer(lines, format, config.enable_syntax)
  local win = require("custom.ui.window").open_raw(buf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    style = "minimal",
    border = border,
    zindex = 150,
    focusable = true,
  })

  set_window_style(win, format, true)
  update_chrome(win, lines, format, spec.command)
  pcall(vim.api.nvim_win_set_cursor, win, { 1, 0 })

  local function close()
    if vim.api.nvim_win_is_valid(win) then
      pcall(vim.api.nvim_win_close, win, true)
    end
  end

  apply_mappings(buf, win, lines, format, command, close)

  vim.keymap.set("n", "s", function()
    close()
    open_split("split", lines, format, spec.command)
  end, { buffer = buf, noremap = true, silent = true })

  vim.keymap.set("n", "v", function()
    close()
    open_split("vsplit", lines, format, spec.command)
  end, { buffer = buf, noremap = true, silent = true })
end

function M.show_last()
  if not M._last then
    vim.notify("[nvim-cmdline] no saved output yet", vim.log.levels.INFO)
    return
  end

  M.show(M._last)
end

return M
