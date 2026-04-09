-- =============================================================================
--  config/keymaps.lua  ·  Key mappings
--
--  Annotations:
--    [0.12-default] = Neovim 0.12 ships this mapping by DEFAULT (documented
--                     here for awareness / potential overriding).
--    [0.12-new]     = New API used in the mapping definition.
--    [0.11]         = Available since 0.11.
-- =============================================================================

local map = vim.keymap.set
local noremap_s = { noremap = true, silent = true }

-- Clear search highlight
map("n", "<Esc>", "<cmd>nohlsearch<CR>", noremap_s)

map("t", "<C-/>", "<cmd>close<cr>", { desc = "Hide Terminal" })
map(
  "n",
  "<leader>ur",
  "<Cmd>nohlsearch<Bar>diffupdate<Bar>normal! <C-L><CR>",
  { desc = "Redraw / Clear hlsearch / Diff Update" }
)

-- Faster saves
map("n", "<leader>w", "<cmd>w<CR>", noremap_s)

-- [0.12-new] :wall with ++p auto-creates missing parent directories
map("n", "<leader>W", "<cmd>wall ++p<CR>", noremap_s)

-- Window navigation
map("n", "<C-h>", "<C-w>h", noremap_s)
map("n", "<C-j>", "<C-w>j", noremap_s)
map("n", "<C-k>", "<C-w>k", noremap_s)
map("n", "<C-l>", "<C-w>l", noremap_s)

-- Resize windows
map("n", "<C-Up>", "<cmd>resize +2<CR>", noremap_s)
map("n", "<C-Down>", "<cmd>resize -2<CR>", noremap_s)
map("n", "<C-Left>", "<cmd>vertical resize -2<CR>", noremap_s)
map("n", "<C-Right>", "<cmd>vertical resize +2<CR>", noremap_s)

map("n", "n", "nzz", noremap_s)

-- Move lines
map("v", "J", ":m '>+1<CR>gv=gv", noremap_s)
map("v", "K", ":m '<-2<CR>gv=gv", noremap_s)

-- Stay centred when scrolling
map("n", "<C-d>", "<C-d>zz", noremap_s)
map("n", "<C-u>", "<C-u>zz", noremap_s)

-- Paste without replacing clipboard
map("v", "<leader>p", '"_dP', noremap_s)

-- -- =============================================================================
-- --  TABS
-- -- =============================================================================
-- map("n", "<leader>tn", "<cmd>tabnew<CR>", noremap_s)
-- map("n", "<leader>tc", "<cmd>tabclose<CR>", noremap_s)
-- map("n", "]t", "<cmd>tabnext<CR>", noremap_s)
-- map("n", "[t", "<cmd>tabprev<CR>", noremap_s)

-- =============================================================================
--  BUFFERS
-- =============================================================================
-- map("n", "]b", "<cmd>bnext<CR>", noremap_s)
-- map("n", "<leader>bd", "<cmd>bdelete<CR>", noremap_s)
-- map("n", "[b", "<cmd>bprev<CR>", noremap_s)

-- Select All
map("n", "<C-a>", "gg<S-v>G")

-- save file
map({ "i", "n" }, "<C-s>", "<cmd> w <CR>", noremap_s)

-- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
-- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
-- is not what someone will guess without a bit more experience.
--
-- NOTE: This won't work in all terminal emulators/tmux/etc. Try your own mapping
-- or just use <C-\><C-n> to exit terminal mode
map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- Clear highlights on search when pressing <Esc> in normal mode
--  See `:help hlsearch`

map("n", "<Esc>", function()
  vim.cmd("nohlsearch")
  vim.cmd("stopinsert")
end, { silent = true })

-- Move Lines
map("n", "<A-j>", "<cmd>execute 'move .+' . v:count1<cr>==", { desc = "Move Down" })
map("n", "<A-k>", "<cmd>execute 'move .-' . (v:count1 + 1)<cr>==", { desc = "Move Up" })
map("i", "<A-j>", "<esc><cmd>m .+1<cr>==gi", { desc = "Move Down" })
map("i", "<A-k>", "<esc><cmd>m .-2<cr>==gi", { desc = "Move Up" })
map("v", "<A-j>", ":<C-u>execute \"'<,'>move '>+\" . v:count1<cr>gv=gv", { desc = "Move Down" })
map("v", "<A-k>", ":<C-u>execute \"'<,'>move '<-\" . (v:count1 + 1)<cr>gv=gv", { desc = "Move Up" })

-- better indenting
map("v", "<", "<gv")
map("v", ">", ">gv")

-- =============================================================================
--  PLUGIN MANAGER  (vim.pack – 0.12-new)
-- =============================================================================
-- Update all plugins
map("n", "<leader>pu", function()
  vim.pack.update()
end, { desc = "[0.12] vim.pack: update all plugins" })

-- =============================================================================
--  LSP  (using 0.12 new :lsp command and APIs)
-- =============================================================================

-- [0.12-new] :lsp command replaces the old LspInfo / LspRestart / LspLog
-- Compatibility shims so muscle memory still works:
vim.api.nvim_create_user_command("LspInfo", "checkhealth vim.lsp", {
  desc = "[0.12] Show LSP info via :checkhealth",
})
vim.api.nvim_create_user_command("LspRestart", "lsp restart", {
  desc = "[0.12] Restart LSP via :lsp restart",
})
vim.api.nvim_create_user_command("LspLog", function()
  local log = vim.fs.joinpath(vim.fn.stdpath("state"), "lsp.log")
  vim.cmd("edit " .. log)
end, { desc = "[0.12] Open LSP log" })
vim.api.nvim_create_user_command("LspStop", "lsp stop", {
  desc = "[0.12] Stop LSP via :lsp stop",
})

-- Diagnostics
map("n", "<leader>df", vim.diagnostic.open_float, { desc = "Open diagnostic float" })
map("n", "]d", function()
  vim.diagnostic.jump({
    count = 1,
    float = true,
  })
end, { desc = "Next diagnostic" })
map("n", "[d", function()
  vim.diagnostic.jump({
    count = -1,
    float = true,
  })
end, { desc = "Prev diagnostic" })

map("n", "<leader>dq", vim.diagnostic.setqflist, { desc = "Diagnostics → quickfix" })

-- [0.12-new] vim.diagnostic.status() – returns e.g. "E:2 W:1"
map("n", "<leader>ds", function()
  vim.notify("Diagnostics: " .. vim.diagnostic.status(), vim.log.levels.INFO)
end, { desc = "[0.12] Show diagnostic status string" })

-- [0.12-new] vim.lsp.buf.workspace_diagnostics()
map("n", "<leader>dw", function()
  vim.lsp.buf.workspace_diagnostics()
end, { desc = "[0.12] Workspace diagnostics" })

-- =============================================================================
--  BUILT-IN OPTIONAL PLUGINS  (0.12-new)
-- =============================================================================

-- [0.12-new] :Undotree  (packadd nvim.undotree)
map("n", "<leader>u", "<cmd>Undotree<CR>", { desc = "[0.12] Toggle undotree" })

-- [0.12-new] :DiffTool  (packadd nvim.difftool)
map("n", "<leader>dt", "<cmd>DiffTool<CR>", { desc = "[0.12] Open DiffTool" })

-- =============================================================================
--  GIT  (gitsigns)
-- =============================================================================
map("n", "]g", function()
  require("gitsigns").nav_hunk("next")
end, { desc = "Next git hunk" })

map("n", "[g", function()
  require("gitsigns").nav_hunk("prev")
end, { desc = "Prev git hunk" })

map("n", "<leader>gs", function()
  require("gitsigns").stage_hunk()
end, { desc = "Stage hunk" })

map("n", "<leader>gr", function()
  require("gitsigns").reset_hunk()
end, { desc = "Reset hunk" })

map("n", "<leader>gp", function()
  require("gitsigns").preview_hunk()
end, { desc = "Preview hunk" })

map("n", "<leader>gb", function()
  require("gitsigns").blame_line({ full = true })
end, {
  desc = "Blame line",
})

-- =============================================================================
--  RESTART  (0.12-new)
-- =============================================================================
-- [0.12-new] :restart restarts Neovim and reattaches the current UI.
--  Combine with a session plugin for seamless reload.
map("n", "<leader>R", "<cmd>restart<CR>", { desc = "[0.12] Restart Neovim" })

-- Close special windows with q
local close_ft = { "help", "qf", "checkhealth", "lspinfo", "startuptime" }
vim.api.nvim_create_autocmd("FileType", {
  pattern = close_ft,
  callback = function(ev)
    map("n", "q", "<cmd>close<CR>", { buffer = ev.buf, silent = true })
  end,
})
