_G._print = print
print = function(...)
  local info = debug.getinfo(2, 'Sl')
  _G._print('PRINT from:', info.short_src, info.currentline, ...)
end

vim.notify = function(msg, ...)
  print('NOTIFY:', msg)
end

local original_echo = vim.api.nvim_echo
vim.api.nvim_echo = function(chunks, history, opts)
  print('ECHO:', vim.inspect(chunks))
  return original_echo(chunks, history, opts)
end

---@diagnostic disable-next-line: deprecated
vim.uv = vim.uv or vim.loop
require 'config.lazy'
