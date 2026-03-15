return {
  -- ── gitsigns.nvim ──────────────────────────────────────────────────────────
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },

    opts = {
      -- ── Gutter signs ────────────────────────────────────────────────────
      signs = {
        add          = { text = "▎" },
        change       = { text = "▎" },
        delete       = { text = "" },
        topdelete    = { text = "" },
        changedelete = { text = "▎" },
        untracked    = { text = "▎" },
      },

      -- ── Sign staging area ────────────────────────────────────────────────
      signs_staged = {
        add          = { text = "▎" },
        change       = { text = "▎" },
        delete       = { text = "" },
        topdelete    = { text = "" },
        changedelete = { text = "▎" },
      },
      signs_staged_enable = true,

      -- Show word-level diff in preview
      word_diff = false,  -- enable with <leader>hw

      -- ── Current line blame ───────────────────────────────────────────────
      current_line_blame = false,  -- toggle with <leader>hB
      current_line_blame_opts = {
        virt_text          = true,
        virt_text_pos      = "eol",  -- end of line
        delay              = 800,    -- ms delay before showing
        ignore_whitespace  = false,
      },

    current_line_blame_formatter = '     <author> • <author_time:%Y-%m-%d %H:%M> • <summary>',
      -- current_line_blame_formatter = "<author>, <author_time:%Y-%m-%d> - <summary>",

      -- ── On attach: buffer-local keymaps ─────────────────────────────────
      on_attach = function(bufnr)
        local gs = package.loaded.gitsigns

        local function map(mode, lhs, rhs, desc)
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
        map("n", "<leader>hs", gs.stage_hunk,                            "Stage hunk")
        map("n", "<leader>hr", gs.reset_hunk,                            "Reset hunk")
        map("n", "<leader>hS", gs.stage_buffer,                          "Stage buffer")
        map("n", "<leader>hR", gs.reset_buffer,                          "Reset buffer")
        map("n", "<leader>hu", gs.undo_stage_hunk,                       "Undo stage hunk")

        -- Range operations (visual mode — stage only selected lines)
        map("v", "<leader>hs", function()
          gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
        end, "Stage hunk (range)")
        map("v", "<leader>hr", function()
          gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
        end, "Reset hunk (range)")

        -- Preview / blame
        map("n", "<leader>hp", gs.preview_hunk,                          "Preview hunk")
        map("n", "<leader>hb", function() gs.blame_line({ full = true }) end, "Blame line (full)")
        map("n", "<leader>hB", gs.toggle_current_line_blame,             "Toggle line blame")
        map("n", "<leader>hw", gs.toggle_word_diff,                      "Toggle word diff")

        -- Diff
        map("n", "<leader>hd", gs.diffthis,                              "Diff this")
        map("n", "<leader>hD", function() gs.diffthis("~") end,          "Diff this (staged)")

        -- Text object: operate on hunks with ih (e.g. "vih" to select hunk)
        map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", "Select hunk")
      end,
    },
  }
}
