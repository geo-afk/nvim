local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

local G = augroup("nvim12_config", { clear = true })
local QC = augroup("QuickClose", { clear = true })
local RS = augroup("ResizeSplits", { clear = true })
local AQ = augroup("AutoQuickfix", { clear = true })

-- ── Angular: project setup ────────────────────────────────────────────────────
autocmd("FileType", {
  pattern = { "typescript", "html" },
  callback = function(ev)
    local utils = require("utils")
    if not utils.is_angular_project(ev.buf) then
      return
    end

    -- Toggle .ts ↔ .html
    vim.keymap.set("n", "<leader>at", function()
      local name = vim.api.nvim_buf_get_name(0)
      if name:match("%.ts$") then
        vim.cmd("edit " .. name:gsub("%.ts$", ".html"))
      elseif name:match("%.html$") then
        vim.cmd("edit " .. name:gsub("%.html$", ".ts"))
      end
    end, { buffer = ev.buf, desc = "Toggle Angular .ts ↔ .html" })

    -- Start Treesitter for Angular templates
    if ev.match == "html" and utils.should_use_angular_parser(vim.api.nvim_buf_get_name(ev.buf)) then
      pcall(vim.treesitter.start, ev.buf, "angular")
    end
  end,
})

-- ── Relative numbers toggle in insert mode ────────────────────────────────────
autocmd("InsertEnter", { group = G, command = "setlocal norelativenumber" })
autocmd("InsertLeave", { group = G, command = "setlocal relativenumber" })

-- ── Spell for prose files ─────────────────────────────────────────────────────
autocmd({ "BufRead", "BufNewFile" }, {
  group = G,
  pattern = { "*.txt", "*.md", "*.tex" },
  callback = function()
    vim.opt_local.spell = true
    vim.opt_local.spelllang = "en"
  end,
})

-- ── Yank highlight ────────────────────────────────────────────────────────────
autocmd("TextYankPost", {
  group = G,
  callback = function()
    vim.hl.on_yank({ higroup = "IncSearch", timeout = 150 })
  end,
})

-- ── Strip trailing whitespace (non-binary, <1 MB) ────────────────────────────
autocmd("BufWritePre", {
  group = G,
  pattern = "*",
  callback = function(ev)
    local bo = vim.bo[ev.buf]
    if bo.binary or bo.buftype ~= "" then
      return
    end
    local stats = vim.uv.fs_stat(vim.api.nvim_buf_get_name(ev.buf))
    if stats and stats.size > 1024 * 1024 then
      return
    end
    local pos = vim.api.nvim_win_get_cursor(0)
    vim.cmd("silent! lockmarks keepjumps %s/\\s\\+$//e")
    vim.api.nvim_win_set_cursor(0, pos)
  end,
})

-- ── Restore cursor to last position ──────────────────────────────────────────
autocmd("BufReadPost", {
  group = G,
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    if mark[1] > 0 and mark[1] <= vim.api.nvim_buf_line_count(0) then
      vim.api.nvim_win_set_cursor(0, mark)
    end
  end,
})

-- ── Auto-resize splits ────────────────────────────────────────────────────────
autocmd("VimResized", {
  group = G,
  callback = function()
    vim.cmd("tabdo wincmd =")
  end,
})

autocmd("VimResized", {
  group = RS,
  callback = function()
    vim.cmd("tabdo wincmd =")
  end,
})

-- ── Disable auto-comment on new lines ────────────────────────────────────────
autocmd("FileType", {
  group = G,
  callback = function()
    vim.opt_local.formatoptions:remove({ "c", "r", "o" })
  end,
})

-- ── MarkSet: visual feedback (0.12-new) ──────────────────────────────────────
autocmd("MarkSet", {
  group = G,
  desc = "[0.12] Echo mark on set",
  callback = function(ev)
    local d = ev.data or {}
    local mark = d.mark or "?"
    local line = (d.pos or {})[1] or "?"
    vim.notify(("Mark '%s' set at line %s"):format(mark, line), vim.log.levels.INFO)
  end,
})

-- ── TabClosedPre: warn about unsaved buffers (0.12-new) ──────────────────────
autocmd("TabClosedPre", {
  group = G,
  desc = "[0.12] Warn on unsaved buffers before tab close",
  callback = function(ev)
    local tabnr = ev.data and ev.data.tabnr
    if not tabnr then
      return
    end
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabnr)) do
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.bo[buf].modified then
        vim.notify(("Tab %d has unsaved changes in buffer %d"):format(tabnr, buf), vim.log.levels.WARN)
      end
    end
  end,
})

-- ── CmdlineLeavePre hook (0.12-new) ──────────────────────────────────────────
autocmd("CmdlineLeavePre", { group = G, desc = "[0.12] CmdlineLeavePre hook", callback = function() end })

-- ── LSP progress via nvim_echo (0.12-enhanced) ───────────────────────────────
autocmd("LspProgress", {
  group = G,
  desc = "[0.12] LSP progress via nvim_echo",
  callback = function(ev)
    local ok, value = pcall(function()
      return ev.data.params.value
    end)
    if not ok or not value then
      return
    end
    vim.api.nvim_echo({ { value.message or "", "Comment" } }, false, {
      id = "lsp." .. ev.data.client_id,
      kind = "progress",
      source = "vim.lsp",
      title = value.title,
      status = value.kind ~= "end" and "running" or "success",
      percent = value.percentage,
    })
  end,
})

-- ── Smart hlsearch ────────────────────────────────────────────────────────────
autocmd("InsertEnter", {
  group = G,
  callback = function()
    vim.opt.hlsearch = false
  end,
})
autocmd("InsertLeave", {
  group = G,
  callback = function()
    if vim.v.hlsearch == 1 then
      vim.opt.hlsearch = true
    end
  end,
})

-- ── DiffTextAdd / FloatBorder highlights (0.12-new) ─────────────────────────
autocmd("ColorScheme", {
  group = G,
  pattern = "*",
  callback = function()
    vim.api.nvim_set_hl(0, "DiffTextAdd", { bg = "#1c3a2a", fg = "#73daca", update = true })
    vim.api.nvim_set_hl(0, "FloatBorder", { fg = "#7dcfff", update = true })
    vim.api.nvim_set_hl(0, "SnippetTabstopActive", { underline = true, sp = "#e0af68" })
    vim.api.nvim_set_hl(0, "PmenuBorder", { fg = "#414868" })
    vim.api.nvim_set_hl(0, "PmenuShadow", { bg = "#1a1b26" })
  end,
})

vim.api.nvim_exec_autocmds("ColorScheme", { pattern = "*", group = G })

-- ── Startup args (0.12-new) ───────────────────────────────────────────────────
autocmd("VimEnter", {
  group = G,
  once = true,
  callback = function()
    local args = vim.v.argf
    if args and #args > 0 then
      vim.notify("Startup args: " .. table.concat(args, ", "), vim.log.levels.INFO)
    end
  end,
})

-- ── Terminal busy flag (0.12) ─────────────────────────────────────────────────
autocmd("TermOpen", {
  group = G,
  callback = function(ev)
    if vim.api.nvim_buf_is_valid(ev.buf) then
      vim.bo[ev.buf].busy = 1
    end
  end,
})
autocmd("TermClose", {
  group = G,
  callback = function(ev)
    if vim.api.nvim_buf_is_valid(ev.buf) then
      vim.bo[ev.buf].busy = 0
    end
  end,
})

-- ── Quick-close utility buffers ───────────────────────────────────────────────
autocmd("FileType", {
  group = QC,
  pattern = { "qf", "help", "man", "dap-float", "dapui_*" },
  callback = function(ev)
    vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = ev.buf, silent = true, noremap = true })
  end,
})

-- ── Environment Files (.env) ──────────────────────────────────────────────────
autocmd({ "BufRead", "BufNewFile" }, {
  group = G,
  pattern = { ".env", ".env.*" },
  callback = function(ev)
    vim.bo[ev.buf].filetype = "dotenv"
    vim.diagnostic.enable(false, { bufnr = ev.buf })
  end,
})

-- ── Auto-open quickfix ────────────────────────────────────────────────────────
autocmd("QuickFixCmdPost", {
  group = AQ,
  pattern = "[^l]*",
  command = "cwindow",
})
