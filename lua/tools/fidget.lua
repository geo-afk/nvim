-- Simple fidget.nvim configuration for LazyVim
-- Save as: lua/plugins/fidget.lua (not in tools folder!)

return {
  "j-hui/fidget.nvim",
  event = "LspAttach",
  config = function()
    require("fidget").setup({
      -- LSP Progress configuration
      progress = {
        poll_rate = 0,
        suppress_on_insert = false,
        ignore_done_already = false,
        ignore_empty_message = false,

        display = {
          render_limit = 16,
          done_ttl = 3,
          done_icon = "✔",
          done_style = "Constant",
          progress_ttl = math.huge,
          progress_icon = { "dots" },
          progress_style = "WarningMsg",
          group_style = "Title",
          icon_style = "Question",
          priority = 30,
          skip_history = true,

          -- Safe function definitions (no requires during config)
          format_annote = function(msg)
            return msg.title
          end,

          format_group_name = function(group)
            return tostring(group)
          end,

          -- Simple overrides for common LSP servers
          overrides = {
            lua_ls = { name = "lua-ls" },
            tsserver = { name = "typescript" },
            eslint = { name = "eslint" },
            pyright = { name = "pyright" },
          },
        },

        lsp = {
          progress_ringbuf_size = 0,
          log_handler = false,
        },
      },

      -- Notification configuration
      notification = {
        poll_rate = 10,
        filter = vim.log.levels.INFO,
        history_size = 128,
        override_vim_notify = false,

        view = {
          stack_upwards = true,
          icon_separator = " ",
          group_separator = "---",
          group_separator_hl = "Comment",

          render_message = function(msg, cnt)
            return cnt == 1 and msg or string.format("(%dx) %s", cnt, msg)
          end,
        },

        window = {
          normal_hl = "Comment",
          winblend = 100,
          border = "none",
          zindex = 45,
          max_width = 0,
          max_height = 0,
          x_padding = 1,
          y_padding = 0,
          align = "bottom",
          relative = "editor",
        },
      },

      -- Plugin integrations
      integration = {
        ["nvim-tree"] = {
          enable = true,
        },
      },

      -- Logging
      logger = {
        level = vim.log.levels.WARN,
        max_size = 10000,
        float_precision = 0.01,
        path = string.format("%s/fidget.nvim.log", vim.fn.stdpath("cache")),
      },
    })
  end,
}
