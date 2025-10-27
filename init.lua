_G._print = print
print = function(...)
  local info = debug.getinfo(2, 'Sl')
  _G._print('PRINT from:', info.short_src, info.currentline, ...)
end

require 'config.lazy'
