-- =============================================================================
--  plugins/toggleterm.lua  ·  toggleterm.nvim
--
--  Includes numbered terminals 1-5, scooter integration, and terminal
--  navigation keymaps. which-key groups are registered if which-key is loaded.
-- =============================================================================

vim.pack.add({ { src = "https://github.com/akinsho/toggleterm.nvim" } })

local ok, toggleterm = pcall(require, "toggleterm")
if not ok then return end

-- ── Dynamic dir: use the previous buffer's directory, fallback to cwd ─────────
local function get_dynamic_dir()
  local prev = vim.fn.bufname(vim.fn.bufnr("#"))
  if prev ~= "" and not prev:match("^term://") then
    local dir = vim.fn.fnamemodify(prev, ":p:h")
    if vim.fn.isdirectory(dir) == 1 then return dir end
  end
  return vim.fn.getcwd()
end

local function on_open_terminal(term)
  term:send("clear", true)
  vim.cmd("startinsert!")
end

-- ── Core setup ────────────────────────────────────────────────────────────────
toggleterm.setup({
  size = function(term)
    if term.direction == "horizontal" then return 17 end
  end,
  open_mapping = [[<C-\>]],
  direction    = "horizontal",
  close_on_exit = true,
  dir          = get_dynamic_dir,
  on_open      = function(term)
    term:send("clear", true)
    vim.cmd("startinsert!")
  end,
})

-- ── Numbered terminal instances (2-5) ────────────────────────────────────────
local Terminal    = require("toggleterm.terminal").Terminal
local terminal_count = 5
local terminals   = {}

for idx = 2, terminal_count do
  terminals[idx] = Terminal:new({
    direction    = "horizontal",
    hidden       = false,
    display_name = "Terminal " .. idx,
    dir          = get_dynamic_dir(),
    on_open      = on_open_terminal,
  })
  _G["_TERMINAL_" .. idx .. "_TOGGLE"] = function()
    terminals[idx]:toggle()
  end
end

-- ── Scooter integration ───────────────────────────────────────────────────────
local scooter_term = nil

local function open_scooter()
  if not scooter_term then
    scooter_term = Terminal:new({
      cmd          = "scooter",
      direction    = "float",
      close_on_exit = true,
      on_open      = function() vim.cmd("startinsert!") end,
      on_exit      = function() scooter_term = nil end,
    })
  end
  scooter_term:open()
end

_G.EditLineFromScooter = function(file_path, line)
  if scooter_term and scooter_term:is_open() then scooter_term:close() end
  local current = vim.fn.expand("%:p")
  local target  = vim.fn.fnamemodify(file_path, ":p")
  if current ~= target then vim.cmd.edit(vim.fn.fnameescape(file_path)) end
  vim.api.nvim_win_set_cursor(0, { line, 0 })
end

_G.OpenScooterSearchText = function(search_text)
  if scooter_term and scooter_term:is_open() then scooter_term:close() end
  local escaped = vim.fn.shellescape(search_text:gsub("\r?\n", " "))
  scooter_term = Terminal:new({
    cmd          = "scooter --search-text " .. escaped,
    direction    = "float",
    close_on_exit = true,
    on_open      = function() vim.cmd("startinsert!") end,
    on_exit      = function() scooter_term = nil end,
  })
  scooter_term:open()
end

vim.keymap.set("n", "<leader>ts", open_scooter, { desc = "Open scooter" })
vim.keymap.set("v", "<leader>tr",
  '"ay<ESC><cmd>lua OpenScooterSearchText(vim.fn.getreg("a"))<CR>',
  { desc = "Search selected text in scooter" })

-- ── Terminal-mode navigation ──────────────────────────────────────────────────
local function set_terminal_keymaps()
  local o = { buffer = 0, noremap = true, silent = true }
  vim.keymap.set("t", "<Esc>",   [[<C-\><C-n>]],       o)
  vim.keymap.set("t", "<C-h>",   [[<C-\><C-n><C-W>h]], o)
  vim.keymap.set("t", "<C-j>",   [[<C-\><C-n><C-W>j]], o)
  vim.keymap.set("t", "<C-k>",   [[<C-\><C-n><C-W>k]], o)
  vim.keymap.set("t", "<C-l>",   [[<C-\><C-n><C-W>l]], o)
end

vim.api.nvim_create_autocmd("TermOpen", {
  pattern  = "term://*",
  callback = function()
    set_terminal_keymaps()
    vim.opt_local.number         = false
    vim.opt_local.relativenumber = false
    vim.opt_local.signcolumn     = "no"
  end,
})

-- ── Static keymaps ────────────────────────────────────────────────────────────
vim.keymap.set("n", "<leader>tt", "<cmd>ToggleTerm<CR>",    { desc = "Toggle default terminal" })
vim.keymap.set("n", "<leader>t1", "<cmd>1ToggleTerm<CR>",   { desc = "Terminal 1" })
for idx = 2, terminal_count do
  vim.keymap.set("n", "<leader>t" .. idx,
    "<cmd>lua _TERMINAL_" .. idx .. "_TOGGLE()<CR>",
    { desc = "Terminal " .. idx })
end

-- ── which-key group registration ─────────────────────────────────────────────
local wk_ok, wk = pcall(require, "which-key")
if wk_ok then
  local mappings = {
    { "<leader>t",  group = "Terminal" },
    { "<leader>tt", "<cmd>ToggleTerm<CR>", desc = "Toggle Default Terminal" },
    { "<leader>t1", "<cmd>1ToggleTerm<CR>", desc = "Terminal 1" },
    { "<leader>ts", desc = "Open Scooter" },
    { "<leader>tr", desc = "Search Selected Text (Scooter)", mode = "v" },
  }
  for idx = 2, terminal_count do
    table.insert(mappings, {
      "<leader>t" .. idx,
      "<cmd>lua _TERMINAL_" .. idx .. "_TOGGLE()<CR>",
      desc = "Terminal " .. idx,
    })
  end
  wk.add(mappings)
end
