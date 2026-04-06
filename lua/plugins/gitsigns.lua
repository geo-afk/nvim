-- =============================================================================
--  plugins/gitsigns.lua  ·  gitsigns.nvim
-- =============================================================================

vim.pack.add({ { src = "https://github.com/lewis6991/gitsigns.nvim" } })

local ok, gitsigns = pcall(require, "gitsigns")
if not ok then return end

gitsigns.setup({
  signs = {
    add          = { text = "▎" },
    change       = { text = "▎" },
    delete       = { text = "" },
    topdelete    = { text = "" },
    changedelete = { text = "▎" },
    untracked    = { text = "▎" },
  },
  signs_staged = {
    add          = { text = "▎" },
    change       = { text = "▎" },
    delete       = { text = "" },
    topdelete    = { text = "" },
    changedelete = { text = "▎" },
  },
  signs_staged_enable = true,
  word_diff           = false,
  current_line_blame  = false,
  current_line_blame_opts = {
    virt_text        = true,
    virt_text_pos    = "eol",
    delay            = 800,
    ignore_whitespace = false,
  },
  current_line_blame_formatter = "     <author> • <author_time:%Y-%m-%d %H:%M> • <summary>",

  on_attach = function(bufnr)
    local gs  = package.loaded.gitsigns
    local map = function(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = "Git: " .. desc })
    end

    -- Hunk navigation
    map("n", "]h", function()
      if vim.wo.diff then return "]h" end
      vim.schedule(function() gs.next_hunk() end)
      return "<Ignore>"
    end, "Next hunk")

    map("n", "[h", function()
      if vim.wo.diff then return "[h" end
      vim.schedule(function() gs.prev_hunk() end)
      return "<Ignore>"
    end, "Prev hunk")

    -- Hunk operations
    map("n", "<leader>hs",  gs.stage_hunk,                            "Stage hunk")
    map("n", "<leader>hr",  gs.reset_hunk,                            "Reset hunk")
    map("n", "<leader>hS",  gs.stage_buffer,                          "Stage buffer")
    map("n", "<leader>hR",  gs.reset_buffer,                          "Reset buffer")
    map("n", "<leader>hu",  gs.undo_stage_hunk,                       "Undo stage hunk")
    map("n", "<leader>hp",  gs.preview_hunk,                          "Preview hunk")
    map("n", "<leader>hb",  function() gs.blame_line({ full = true }) end, "Blame line")
    map("n", "<leader>hB",  gs.toggle_current_line_blame,             "Toggle line blame")
    map("n", "<leader>hw",  gs.toggle_word_diff,                      "Toggle word diff")
    map("n", "<leader>hd",  gs.diffthis,                              "Diff this")
    map("n", "<leader>hD",  function() gs.diffthis("~") end,          "Diff this (staged)")

    -- Visual range operations
    map("v", "<leader>hs", function()
      gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
    end, "Stage hunk (range)")
    map("v", "<leader>hr", function()
      gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
    end, "Reset hunk (range)")

    -- Text object
    map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", "Select hunk")
  end,
})
