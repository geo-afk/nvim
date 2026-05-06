local buffer = require("custom.ui.buffer")
local window = require("custom.ui.window")

local M = {}

local function paste_from_clipboard()
  local text = vim.fn.getreg("+")
  if text == nil or text == "" then
    text = vim.fn.getreg("*")
  end
  if text ~= nil and text ~= "" then
    vim.api.nvim_paste(text, true, -1)
  end
end

function M.open(opts, on_submit)
  opts = opts or {}
  on_submit = on_submit or opts.on_submit or function() end

  local prompt = opts.prompt or ""
  local default = opts.default or ""
  local width = opts.width
  if not width then
    local title_width = vim.fn.strdisplaywidth(opts.title or " Input ")
    local footer_width = vim.fn.strdisplaywidth(opts.footer or "")
    width = math.max(28, prompt:len() + default:len() + 6, title_width + 6, footer_width + 4)
    width = math.min(width, math.max(28, vim.o.columns - 8))
  end

  local buf = buffer.create({
    buftype = opts.buftype or "prompt",
    bufhidden = "wipe",
    filetype = opts.filetype or "custom_ui_input",
    modifiable = true,
    disable_completion = opts.disable_completion ~= false,
  })

  vim.fn.prompt_setprompt(buf, prompt)

  local win = window.open(buf, {
    enter = true,
    width = width,
    height = 1,
    border = opts.border or "rounded",
    title = opts.title or " Input ",
    title_pos = opts.title_pos or "center",
    footer = opts.footer,
    footer_pos = opts.footer_pos or "center",
    zindex = opts.zindex or 250,
    noautocmd = opts.noautocmd,
    options = opts.win_options,
  })
  window.configure_float(win, opts.float_options or {})

  local closed = false
  local function close(value, cancelled)
    if closed then
      return
    end
    closed = true
    window.close_pair(win, buf)
    vim.schedule(function()
      if cancelled then
        on_submit(nil)
      else
        on_submit(value)
      end
    end)
  end

  vim.fn.prompt_setcallback(buf, function(text)
    close(text, false)
  end)

  local map_opts = { buffer = buf, silent = true, nowait = true }
  vim.keymap.set({ "i", "n" }, "<Esc>", function()
    close(nil, true)
  end, map_opts)
  vim.keymap.set({ "i", "n" }, "<C-c>", function()
    close(nil, true)
  end, map_opts)
  vim.keymap.set("i", "<C-v>", paste_from_clipboard, { buffer = buf, silent = true })
  vim.keymap.set("i", "<S-Insert>", paste_from_clipboard, { buffer = buf, silent = true })

  vim.schedule(function()
    if not vim.api.nvim_win_is_valid(win) then
      return
    end
    vim.cmd("startinsert!")
    if default ~= "" then
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(default, true, false, true), "i", false)
    end
  end)

  return { buf = buf, win = win, close = close }
end

return M
