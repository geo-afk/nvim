-- =============================================================================
--  plugins/gitsigns.lua  ·  gitsigns.nvim
-- =============================================================================

vim.pack.add({ { src = "https://github.com/lewis6991/gitsigns.nvim" } })

local ok, gitsigns = pcall(require, "gitsigns")
if not ok then
  return
end

gitsigns.setup({
  signs = {
    add = { text = "▎", hl = "GitSignsAdd" },
    change = { text = "▎", hl = "GitSignsChange" },
    delete = { text = "▁", hl = "GitSignsDelete" },
    topdelete = { text = "▔", hl = "GitSignsDelete" },
    changedelete = { text = "▎", hl = "GitSignsChange" },
    untracked = { text = "▎", hl = "GitSignsAdd" },
  },
  signs_staged = {
    add = { text = "▎", hl = "GitSignsStagedAdd" },
    change = { text = "▎", hl = "GitSignsStagedChange" },
    delete = { text = "▁", hl = "GitSignsStagedDelete" },
    topdelete = { text = "▔", hl = "GitSignsStagedDelete" },
    changedelete = { text = "▎", hl = "GitSignsStagedChange" },
  },
  signs_staged_enable = true,

  sign_priority = 6,
  update_debounce = 100,
  max_file_length = 40000,

  word_diff = false,
  current_line_blame = true, -- ENABLED BY DEFAULT!
  current_line_blame_opts = {
    virt_text = true,
    virt_text_pos = "eol",
    delay = 800,
    ignore_whitespace = false,
  },
  -- Enhanced formatter with icons
  current_line_blame_formatter = "    <author> •   <author_time:%Y-%m-%d %H:%M> •   <summary>",

  on_attach = function(bufnr)
    local gs = package.loaded.gitsigns
    local map = function(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = "Git: " .. desc })
    end

    -- VIBRANT COLORS with depth
    -- Add: Bright forest green
    vim.api.nvim_set_hl(0, "GitSignsAdd", { fg = "#22dd22", bg = "NONE" })
    -- Change: Bright golden yellow
    vim.api.nvim_set_hl(0, "GitSignsChange", { fg = "#ffff00", bg = "NONE" })
    -- Delete: Bright crimson red
    vim.api.nvim_set_hl(0, "GitSignsDelete", { fg = "#ff3333", bg = "NONE" })

    -- Staged versions (slightly muted but still vibrant)
    vim.api.nvim_set_hl(0, "GitSignsStagedAdd", { fg = "#00cc00", bg = "NONE" })
    vim.api.nvim_set_hl(0, "GitSignsStagedChange", { fg = "#ffaa00", bg = "NONE" })
    vim.api.nvim_set_hl(0, "GitSignsStagedDelete", { fg = "#ee2222", bg = "NONE" })

    -- Hunk navigation
    map("n", "]h", function()
      if vim.wo.diff then
        return "]h"
      end
      vim.schedule(function()
        gs.next_hunk()
      end)
      return "<Ignore>"
    end, "Next hunk")

    map("n", "[h", function()
      if vim.wo.diff then
        return "[h"
      end
      vim.schedule(function()
        gs.prev_hunk()
      end)
      return "<Ignore>"
    end, "Prev hunk")

    -- Hunk operations
    map("n", "<leader>gs", gs.stage_hunk, "Stage hunk")
    map("n", "<leader>gr", gs.reset_hunk, "Reset hunk")
    map("n", "<leader>gS", gs.stage_buffer, "Stage buffer")
    map("n", "<leader>gR", gs.reset_buffer, "Reset buffer")
    map("n", "<leader>gu", gs.undo_stage_hunk, "Undo stage hunk")
    map("n", "<leader>gp", gs.preview_hunk, "Preview hunk")
    map("n", "<leader>gb", function()
      gs.blame_line({ full = true })
    end, "Blame line")
    map("n", "<leader>gB", gs.toggle_current_line_blame, "Toggle line blame")
    map("n", "<leader>gw", gs.toggle_word_diff, "Toggle word diff")
    map("n", "<leader>gd", gs.diffthis, "Diff this")
    map("n", "<leader>gD", function()
      gs.diffthis("~")
    end, "Diff this (staged)")

    -- Visual range operations
    map("v", "<leader>gs", function()
      gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
    end, "Stage hunk (range)")
    map("v", "<leader>gr", function()
      gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
    end, "Reset hunk (range)")

    -- Text object
    map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", "Select hunk")

    -- Escape from preview/popup
    map("n", "q", function()
      vim.cmd("pclose")
    end, "Close preview/popup")

    map("n", "<Esc>", function()
      vim.cmd("pclose")
    end, "Close preview/popup (ESC)")
  end,
})
