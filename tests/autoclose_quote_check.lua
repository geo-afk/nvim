vim.opt.shadafile = "NONE"
vim.opt.swapfile = false

dofile(vim.fn.stdpath("config") .. "/init.lua")

vim.cmd("enew")
vim.api.nvim_exec_autocmds("InsertEnter", {})
vim.wait(200)

local found = {}
for _, map in ipairs(vim.api.nvim_get_keymap("i")) do
  if map.lhs == '"' or map.lhs == "'" then
    found[map.lhs] = map.callback
  end
end

assert(type(found['"']) == "function", "double quote insert mapping was not registered")
assert(type(found["'"]) == "function", "single quote insert mapping was not registered")

vim.api.nvim_set_current_line("")
vim.api.nvim_win_set_cursor(0, { 1, 0 })
assert(found['"']() == '""<Left>', "double quote mapping did not autoclose")
assert(found["'"]() == "''<Left>", "single quote mapping did not autoclose")

vim.api.nvim_set_current_line([["]])
vim.api.nvim_win_set_cursor(0, { 1, 0 })
assert(found['"']() == "<Right>", "double quote mapping did not skip over closer")

vim.api.nvim_set_current_line("'")
vim.api.nvim_win_set_cursor(0, { 1, 0 })
assert(found["'"]() == "<Right>", "single quote mapping did not skip over closer")

print("autoclose quote mappings ok")
vim.cmd("qall!")
