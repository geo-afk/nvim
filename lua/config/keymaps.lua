-- =============================================================================
--  config/keymaps.lua  ·  Centralized Key Mappings
-- =============================================================================

local map = vim.keymap.set
local noremap_s = { noremap = true, silent = true }
local diagnostic_jump_float = function(diagnostic, bufnr)
  if diagnostic then
    vim.diagnostic.open_float({ bufnr = bufnr, scope = "cursor" })
  end
end

-- ── 1. General & Editor Navigation ──────────────────────────────────────────
map("n", "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, desc = "Down (wrap-aware)" })
map("n", "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, desc = "Up (wrap-aware)" })

-- Clear search highlight
map("n", "<Esc>", function()
  vim.cmd("nohlsearch")
  vim.cmd("stopinsert")
end, { silent = true, desc = "Clear search highlights" })

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

-- Centered scrolling
map("n", "n", "nzz", noremap_s)
map("n", "<C-d>", "<C-d>zz", noremap_s)
map("n", "<C-u>", "<C-u>zz", noremap_s)

-- Move Lines
map("n", "<A-j>", "<cmd>execute 'move .+' . v:count1<cr>==", { desc = "Move Down" })
map("n", "<A-k>", "<cmd>execute 'move .-' . (v:count1 + 1)<cr>==", { desc = "Move Up" })
map("i", "<A-j>", "<esc><cmd>m .+1<cr>==gi", { desc = "Move Down" })
map("i", "<A-k>", "<esc><cmd>m .-2<cr>==gi", { desc = "Move Up" })
map("v", "<A-j>", ":<C-u>execute \"'<,'>move '>+\" . v:count1<cr>gv=gv", { desc = "Move Down" })
map("v", "<A-k>", ":<C-u>execute \"'<,'>move '<-\" . (v:count1 + 1)<cr>gv=gv", { desc = "Move Up" })

-- Better indenting
map("v", "<", "<gv")
map("v", ">", ">gv")

-- Select All
map("n", "<C-a>", "gg<S-v>G", { desc = "Select all" })

-- Save file
map({ "i", "n" }, "<C-s>", "<cmd>w<CR>", noremap_s)
map("n", "<leader>ww", "<cmd>w<CR>", { desc = "Save file" })
map("n", "<leader>wa", "<cmd>wall ++p<CR>", { desc = "Save all (auto-parents)" })

-- Paste without replacing clipboard
map("v", "<leader>P", '"_dP', vim.tbl_extend("force", noremap_s, { desc = "Paste without yanking" }))

-- ── 2. File Explorer & Buffers ──────────────────────────────────────────────
-- Explorer
map("n", "<leader>e", function()
  require("custom.explorer").toggle()
end, { desc = "Toggle explorer" })

-- Tabline / Buffers
map("n", "<Tab>", function()
  require("custom.tabline").next_buffer()
end, { desc = "Next buffer" })
map("n", "<S-Tab>", function()
  require("custom.tabline").prev_buffer()
end, { desc = "Prev buffer" })
map("n", "<A-c>", function()
  require("custom.tabline").close_buffer()
end, { desc = "Close buffer" })
-- map("n", "<leader>b<", function()
--   require("custom.tabline").move_buffer_left()
-- end, { desc = "Move buffer left" })
-- map("n", "<leader>b>", function()
--   require("custom.tabline").move_buffer_right()
-- end, { desc = "Move buffer right" })

-- ── 3. LSP & Diagnostics ───────────────────────────────────────────────────
map("n", "gd", vim.lsp.buf.definition, { desc = "LSP: Definition" })
map("n", "<leader>ca", function()
  require("custom.code_action").open()
end, { desc = "LSP: Code Action" })
map("x", "<leader>ca", function()
  require("custom.code_action").open()
end, { desc = "LSP: Code Action" })
map("n", "<leader>cA", function()
  require("custom.code_action").open({ open_preview = true })
end, { desc = "LSP: Code Action (preview)" })
map("n", "<leader>ck", function()
  require("custom.lsp_keymapper").open()
end, { desc = "LSP keymapper" })

-- Diagnostics
map("n", "<leader>df", vim.diagnostic.open_float, { desc = "Open diagnostic float" })
map("n", "]d", function()
  vim.diagnostic.jump({ count = 1, on_jump = diagnostic_jump_float })
end, { desc = "Next diagnostic" })
map("n", "[d", function()
  vim.diagnostic.jump({ count = -1, on_jump = diagnostic_jump_float })
end, { desc = "Prev diagnostic" })
map("n", "<leader>dq", vim.diagnostic.setqflist, { desc = "Diagnostics → quickfix" })
map("n", "<leader>ds", function()
  vim.notify("Diagnostics: " .. vim.diagnostic.status(), vim.log.levels.INFO)
end, { desc = "Diagnostic status" })
map("n", "<leader>dw", function()
  vim.lsp.buf.workspace_diagnostics()
end, { desc = "Workspace diagnostics" })

-- Formatting
map("n", "<leader>fi", "<cmd>ConformInfo<CR>", { desc = "Conform info" })

-- ── 4. Git & Terminal ──────────────────────────────────────────────────────
-- Git (Gitsigns)
map("n", "]g", function()
  require("gitsigns").nav_hunk("next")
end, { desc = "Next git hunk" })
map("n", "[g", function()
  require("gitsigns").nav_hunk("prev")
end, { desc = "Prev git hunk" })
map("n", "<leader>gg", function()
  require("custom.float_term.term").create_terminal("lazygit")
end, { desc = "LazyGit" })

-- Terminal mode mappings
map("t", "<Esc><Esc>", [[<C-\><C-n>]], { desc = "Exit terminal mode" })
map("t", "<C-/>", "<cmd>close<cr>", { desc = "Hide Terminal" })

-- ── 5. Search & Telescope ──────────────────────────────────────────────────
-- Telescope
map("n", "<leader><leader>", "<cmd>Telescope current_buffer_fuzzy_find<cr>", { desc = "Buffer search" })
map("n", "<leader>sf", "<cmd>Telescope find_files<cr>", { desc = "Find files" })
map("n", "<leader>sg", "<cmd>Telescope live_grep<cr>", { desc = "Live grep" })
map("n", "<leader>sw", "<cmd>Telescope grep_string<cr>", { desc = "Grep current word" })
map("n", "<leader>sd", "<cmd>Telescope diagnostics<cr>", { desc = "Search diagnostics" })
map("n", "<leader>sk", "<cmd>Telescope keymaps<cr>", { desc = "Search keymaps" })
map("n", "<leader>sh", "<cmd>Telescope help_tags<cr>", { desc = "Search help tags" })
map("n", "<leader>ss", "<cmd>Telescope builtin<cr>", { desc = "Search pickers" })
map("n", "<leader>sr", "<cmd>Telescope resume<cr>", { desc = "Resume search" })
map("n", "<leader>s.", "<cmd>Telescope oldfiles<cr>", { desc = "Recent files" })
map("n", "<leader>si", function()
  require("telescope.builtin").find_files({ hidden = true, no_ignore = true })
end, { desc = "Search hidden files" })
map("n", "<leader>sn", function()
  require("telescope.builtin").find_files({ cwd = vim.fn.stdpath("config") })
end, { desc = "Search Neovim config" })
map("n", "<leader>s/", function()
  require("telescope.builtin").live_grep({ grep_open_files = true, prompt_title = "Live Grep in Open Files" })
end, { desc = "Grep open files" })

-- Flash / Jump
map("n", "s", function()
  require("flash").jump()
end, { desc = "Flash Jump" })
map("n", "S", function()
  require("flash").treesitter()
end, { desc = "Flash Treesitter" })

-- Trouble
map("n", "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", { desc = "Trouble diagnostics" })
map("n", "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", { desc = "Trouble buffer diagnostics" })
map("n", "<leader>xs", "<cmd>Trouble symbols toggle focus=false<cr>", { desc = "Trouble symbols" })
map("n", "<leader>xl", "<cmd>Trouble lsp toggle focus=false win.position=right<cr>", { desc = "Trouble LSP list" })
map("n", "<leader>xL", "<cmd>Trouble loclist toggle<cr>", { desc = "Trouble location list" })
map("n", "<leader>xQ", "<cmd>Trouble qflist toggle<cr>", { desc = "Trouble quickfix list" })

-- ── 6. Plugin Management & Maintenance ──────────────────────────────────────
map("n", "<leader>pu", function()
  vim.pack.update()
end, { desc = "Update plugins" })
map("n", "<leader>pp", function()
  require("custom.pack_manager").open()
end, { desc = "Pack manager" })
map("n", "<leader>pm", "<cmd>Mason<CR>", { desc = "Mason UI" })
map("n", "<leader>uu", "<cmd>Undotree<CR>", { desc = "Undotree" })
map("n", "<leader>nd", "<cmd>DiffTool<CR>", { desc = "DiffTool" })
map("n", "<leader>nr", function()
  local session = vim.fs.joinpath(vim.fn.stdpath("state"), "restart_session.vim")
  vim.cmd("mksession! " .. vim.fn.fnameescape(session))
  vim.cmd("restart source " .. vim.fn.fnameescape(session))
end, { desc = "Restart Neovim" })

-- ── 7. UI Experiments & Others ──────────────────────────────────────────────
map("n", "<leader>ni", "<cmd>NvimInfo<CR>", { desc = "Neovim info float" })
map("n", "<leader>?", function()
  require("which-key").show({ global = false })
end, { desc = "Buffer keymaps" })
