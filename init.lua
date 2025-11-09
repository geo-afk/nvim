_G._print = print
print = function(...)
  local info = debug.getinfo(2, 'Sl')
  _G._print('PRINT from:', info.short_src, info.currentline, ...)
end

---@diagnostic disable-next-line: deprecated
vim.uv = vim.uv or vim.loop
require 'config.lazy'
