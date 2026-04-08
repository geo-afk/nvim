-- =============================================================================
--  config/autocmds.lua  ·  Autocommands
--
--  New 0.12 events are annotated [0.12-new].
--  Changed 0.12 event behaviour is annotated [0.12-changed].
-- =============================================================================

local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

-- ── Helpers ───────────────────────────────────────────────────────────────────
local G = augroup("nvim12_config", { clear = true })

-- =============================================================================
--  GENERAL QoL AUTOCMDS
-- =============================================================================
-- Create an autocmd for both TypeScript and HTML files
autocmd("FileType", {
  pattern = { "typescript", "html" }, -- both filetypes
  callback = function()
    if require("utils").is_angular_project() then
      -- Buffer-local keymap
      vim.keymap.set("n", "<leader>at", function()
        -- Example: Toggle between .ts and .html
        local bufname = vim.api.nvim_buf_get_name(0)
        if bufname:match("%.ts$") then
          vim.cmd("edit " .. bufname:gsub("%.ts$", ".html"))
        elseif bufname:match("%.html$") then
          vim.cmd("edit " .. bufname:gsub("%.html$", ".ts"))
        end
      end, { buffer = true, desc = "Toggle Angular .ts <-> .html" })
    end
  end,
})

autocmd("InsertLeave", { command = "set relativenumber", pattern = "*" })
autocmd("InsertEnter", { command = "set norelativenumber", pattern = "*" })

-- Enable spell checking  certain file types
vim.api.nvim_create_autocmd(
  { "BufRead", "BufNewFile" },
  -- { pattern = { "*.txt", "*.md", "*.tex" }, command = [[setlocal spell<cr> setlocal spelllang=en,de<cr>]] }
  {
    pattern = { "*.txt", "*.md", "*.tex" },
    callback = function()
      vim.opt.spell = true
      vim.opt.spelllang = "en"
    end,
  }
)

-- Highlight on yank
autocmd("TextYankPost", {
  group = G,
  callback = function()
    vim.hl.on_yank({ higroup = "IncSearch", timeout = 150 })
  end,
})

-- Strip trailing whitespace on save (non-binary files)
autocmd("BufWritePre", {
  group = G,
  pattern = "*",
  callback = function()
    if not vim.bo.binary then
      local pos = vim.api.nvim_win_get_cursor(0)
      vim.cmd([[%s/\s\+$//e]])
      vim.api.nvim_win_set_cursor(0, pos)
    end
  end,
})

-- Restore cursor to last position
autocmd("BufReadPost", {
  group = G,
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local line_count = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= line_count then
      vim.api.nvim_win_set_cursor(0, mark)
    end
  end,
})

-- Auto-resize splits on terminal resize
autocmd("VimResized", {
  group = G,
  callback = function()
    vim.cmd("tabdo wincmd =")
  end,
})

-- Disable auto-comment on new lines for most filetypes
autocmd("FileType", {
  group = G,
  callback = function()
    vim.opt_local.formatoptions:remove({ "c", "r", "o" })
  end,
})

--------------------------------------------------------------------------------
-- AUTO-SAVE
--------------------------------------------------------------------------------
autocmd({ "InsertLeave", "TextChanged", "BufLeave", "FocusLost" }, {
  desc = "User: Auto-save",
  callback = function(ctx)
    local saveInstantly = ctx.event == "FocusLost" or ctx.event == "BufLeave"
    local bufnr = ctx.buf
    local bo, b = vim.bo[bufnr], vim.b[bufnr]
    local bufname = ctx.file
    if bo.buftype ~= "" or bo.ft == "gitcommit" or bo.readonly then
      return
    end
    if b.saveQueued and not saveInstantly then
      return
    end

    b.saveQueued = true
    vim.defer_fn(function()
      if not vim.api.nvim_buf_is_valid(bufnr) then
        return
      end

      vim.api.nvim_buf_call(bufnr, function()
        -- saving with explicit name prevents issues when changing `cwd`
        -- `:update!` suppresses "The file has been changed since reading it!!!"
        local vimCmd = ("silent! noautocmd lockmarks update! %q"):format(bufname)
        vim.cmd(vimCmd)
      end)
      b.saveQueued = false
    end, saveInstantly and 0 or 2000)
  end,
})

-- =============================================================================
--  MARK SET  (0.12-new)
-- =============================================================================
-- [0.12-new] MarkSet fires whenever the user sets a mark (currently excludes
--  implicit marks like '[ and '<).  Useful to show visual feedback in the
--  gutter without a plugin.
autocmd("MarkSet", {
  group = G,
  desc = "[0.12] Echo mark name when user sets a mark",
  callback = function(ev)
    -- ev.data.mark = mark character; ev.data.pos = {line, col}
    local mark = ev.data and ev.data.mark or "?"
    local pos = ev.data and ev.data.pos or {}
    vim.notify(string.format("Mark '%s' set at line %s", mark, tostring(pos[1])), vim.log.levels.INFO)
  end,
})

-- =============================================================================
--  SESSION  (0.12-new)
-- =============================================================================
-- [0.12-new] SessionLoadPre fires BEFORE a Session file is loaded.
autocmd("SessionLoadPre", {
  group = G,
  desc = "[0.12] Notify before session load",
  callback = function(ev)
    vim.notify("Loading session: " .. (ev.file or "<unknown>"), vim.log.levels.INFO)
  end,
})

-- =============================================================================
--  TAB MANAGEMENT  (0.12-new)
-- =============================================================================
-- [0.12-new] TabClosedPre fires BEFORE a tabpage is closed.
--  Use it to save or confirm unsaved changes in the tab.
autocmd("TabClosedPre", {
  group = G,
  desc = "[0.12] Warn about unsaved buffers before tab close",
  callback = function(ev)
    local tabnr = ev.data and ev.data.tabnr
    if not tabnr then
      return
    end
    local wins = vim.api.nvim_tabpage_list_wins(tabnr)
    for _, win in ipairs(wins) do
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.bo[buf].modified then
        vim.notify("Tab " .. tabnr .. " has unsaved changes in buffer " .. buf, vim.log.levels.WARN)
      end
    end
  end,
})

-- =============================================================================
--  CMDLINE EVENTS  (0.12-new)
-- =============================================================================
-- [0.12-new] CmdlineLeavePre fires BEFORE preparing to leave command-line mode.
autocmd("CmdlineLeavePre", {
  group = G,
  desc = "[0.12] CmdlineLeavePre – pre-leave hook example",
  callback = function(_ev)
    -- Could be used to validate cmdline content before it executes.
    -- ev.data.cmdline = the current cmdline text
  end,
})

-- [0.12-new] CmdlineLeave now sets v:char to the character that stopped
--  Cmdline mode (e.g. <CR>, <Esc>).
autocmd("CmdlineLeave", {
  group = G,
  desc = "[0.12] Track cmdline exit character via v:char",
  callback = function(_ev)
    -- v:char is now populated:
    -- vim.notify("CmdlineLeave via: " .. vim.v.char)
    -- (commented to avoid noise; enable for debugging)
  end,
})

-- =============================================================================
--  LSP PROGRESS  (0.12-enhanced)
-- =============================================================================
-- nvim_echo() gained Progress kind + id in 0.12, enabling per-client progress
-- bars that update in-place in the cmdline / message area.
autocmd("LspProgress", {
  group = G,
  desc = "[0.12] Show LSP progress via nvim_echo with progress kind",
  callback = function(ev)
    local ok, value = pcall(function()
      return ev.data.params.value
    end)
    if not ok or not value then
      return
    end

    -- [0.12-new] nvim_echo() id parameter de-duplicates progress messages:
    --  same id = update in-place rather than appending a new line.
    vim.api.nvim_echo(
      {
        { (value.message or ""), "Comment" },
      },
      false,
      {
        id = "lsp." .. ev.data.client_id, -- [0.12-new] stable id
        kind = "progress", -- [0.12-new] progress kind
        source = "vim.lsp",
        title = value.title,
        status = value.kind ~= "end" and "running" or "success",
        percent = value.percentage,
      }
    )
  end,
})

-- =============================================================================
--  DIAGNOSTIC RELATED INFORMATION  (0.12-new)
-- =============================================================================
-- In 0.12, vim.diagnostic.open_float() shows DiagnosticRelatedInformation and
-- you can press `gf` inside the float to jump to the referenced location.
-- No extra autocmd needed – this is built-in behaviour.

-- =============================================================================
--  SMART HLSEARCH  (quality-of-life)
-- =============================================================================
-- Turn off hlsearch when entering insert mode
autocmd("InsertEnter", {
  group = G,
  callback = function()
    vim.opt.hlsearch = false
  end,
})
autocmd("InsertLeave", {
  group = G,
  callback = function()
    vim.opt.hlsearch = true
  end,
})

-- =============================================================================
--  DIFF INLINE HIGHLIGHTS  (0.12-new)
-- =============================================================================
-- [0.12-new] hl-DiffTextAdd highlights newly added text within a changed line.
--  We customise it to be distinct from DiffText.
autocmd("ColorScheme", {
  group = G,
  pattern = "*",
  callback = function()
    -- [0.12-new] nvim_set_hl() 'update' flag: update only specified attributes,
    --  leaving all others (bold, italic, bg, …) unchanged.
    vim.api.nvim_set_hl(0, "DiffTextAdd", {
      bg = "#1c3a2a",
      fg = "#73daca",
      update = true, -- [0.12-new]: partial update, don't wipe other attrs
    })

    -- Also partially update FloatBorder without clobbering its background.
    vim.api.nvim_set_hl(0, "FloatBorder", {
      fg = "#7dcfff",
      update = true, -- [0.12-new]
    })

    -- [0.12-new] hl-SnippetTabstopActive – active snippet tabstop
    vim.api.nvim_set_hl(0, "SnippetTabstopActive", {
      underline = true,
      sp = "#e0af68",
    })

    -- [0.12-new] hl-PmenuBorder / PmenuShadow
    vim.api.nvim_set_hl(0, "PmenuBorder", { fg = "#414868" })
    vim.api.nvim_set_hl(0, "PmenuShadow", { bg = "#1a1b26" })
  end,
})

-- Trigger ColorScheme on load to apply immediately
vim.api.nvim_exec_autocmds("ColorScheme", { pattern = "*", group = G })

-- =============================================================================
--  STARTUP ARGS  (0.12-new)
-- =============================================================================
-- [0.12-new] v:argf provides file arguments given at startup.
autocmd("VimEnter", {
  group = G,
  once = true,
  callback = function()
    local args = vim.v.argf -- [0.12-new]: list of file arguments
    if args and #args > 0 then
      vim.notify("Startup args: " .. table.concat(args, ", "), vim.log.levels.INFO)
    end
  end,
})

-- =============================================================================
--  BUSY STATUS  (0.12-new)
-- =============================================================================
-- [0.12-new] 'busy' is a buffer option that marks it as busy (e.g. a running
--  terminal).  The default statusline shows ◐ when busy = true.
--  Mark terminal buffers as busy while the job is running.
autocmd("TermOpen", {
  group = G,
  callback = function(ev)
    vim.bo[ev.buf].busy = true
  end,
})
autocmd("TermClose", {
  group = G,
  callback = function(ev)
    -- Guard: buffer may already be invalid on close
    if vim.api.nvim_buf_is_valid(ev.buf) then
      vim.bo[ev.buf].busy = false
    end
  end,
})
