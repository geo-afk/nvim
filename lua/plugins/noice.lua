-- lua/plugins/noice.lua
-- Enhanced Noice configuration for modern LSP hover

return {
  "folke/noice.nvim",
  opts = function(_, opts)
    -- Ensure opts structure exists
    opts.lsp = opts.lsp or {}
    opts.views = opts.views or {}
    opts.routes = opts.routes or {}
    opts.presets = opts.presets or {}

    -- Enhanced LSP hover configuration
    opts.lsp.hover = {
      enabled = true,
      silent = true,
      view = "hover",
      opts = {},
    }

    -- Enhanced signature help
    opts.lsp.signature = {
      enabled = true,
      auto_open = {
        enabled = true,
        trigger = true,
        luasnip = true,
        throttle = 50,
      },
      view = "hover",
      opts = {},
    }

    -- Documentation hover (for completions)
    opts.lsp.documentation = {
      view = "hover",
      opts = {
        lang = "markdown",
        replace = true,
        render = "plain",
        format = { "{message}" },
        win_options = { concealcursor = "n", conceallevel = 3 },
      },
    }

    -- Override progress messages to be less intrusive
    opts.lsp.progress = {
      enabled = true,
      format = "lsp_progress",
      format_done = "lsp_progress_done",
      throttle = 1000 / 30, -- frequency to update lsp progress message
      view = "mini",
    }

    -- Custom hover view with modern styling
    opts.views.hover = {
      border = {
        style = {
          { "╭", "NoiceBorder" },
          { "─", "NoiceBorder" },
          { "╮", "NoiceBorder" },
          { "│", "NoiceBorder" },
          { "╯", "NoiceBorder" },
          { "─", "NoiceBorder" },
          { "╰", "NoiceBorder" },
          { "│", "NoiceBorder" },
        },
        padding = { 1, 2 },
      },
      position = { row = 2, col = 2 },
      size = {
        max_width = 80,
        max_height = 20,
        width = "auto",
        height = "auto",
      },
      win_options = {
        winblend = 10,
        winhighlight = {
          Normal = "NoicePopup",
          FloatBorder = "NoiceBorder",
          FloatTitle = "NoicePopupTitle",
        },
        wrap = true,
        linebreak = true,
      },
      close = {
        events = { "CursorMoved", "BufLeave", "InsertEnter" },
        keys = { "q", "<Esc>" },
      },
    }

    -- Enhanced cmdline view
    opts.cmdline = {
      enabled = true,
      view = "cmdline_popup",
      opts = {},
      format = {
        cmdline = { pattern = "^:", icon = "", lang = "vim" },
        search_down = { kind = "search", pattern = "^/", icon = " ", lang = "regex" },
        search_up = { kind = "search", pattern = "^%?", icon = " ", lang = "regex" },
        filter = { pattern = "^:%s*!", icon = "$", lang = "bash" },
        lua = { pattern = { "^:%s*lua%s+", "^:%s*lua%s*=%s*", "^:%s*=%s*" }, icon = "", lang = "lua" },
        help = { pattern = "^:%s*he?l?p?%s+", icon = "󰋖" },
      },
    }

    -- Route LSP progress messages to mini view
    table.insert(opts.routes, {
      filter = {
        event = "lsp",
        kind = "progress",
        cond = function(message)
          local client = vim.tbl_get(message.opts, "progress", "client")
          return client == "lua_ls"
        end,
      },
      opts = { skip = true },
    })

    -- Route some annoying messages away
    table.insert(opts.routes, {
      filter = {
        event = "msg_show",
        any = {
          { find = "%d+L, %d+B" },
          { find = "; after #%d+" },
          { find = "; before #%d+" },
          { find = "%d fewer lines" },
          { find = "%d more lines" },
        },
      },
      opts = { skip = true },
    })

    -- Enhanced presets for better UX
    opts.presets.bottom_search = true
    opts.presets.command_palette = true
    opts.presets.long_message_to_split = true
    opts.presets.inc_rename = true
    opts.presets.lsp_doc_border = true

    return opts
  end,

  -- Custom highlight groups for modern appearance
  config = function(_, opts)
    require("noice").setup(opts)

    -- Set up custom highlights
    vim.api.nvim_create_autocmd("ColorScheme", {
      callback = function()
        -- Modern color scheme (adjust these to match your theme)
        local highlights = {
          NoicePopup = { bg = "#1e1e2e", fg = "#cdd6f4" },
          NoiceBorder = { fg = "#89b4fa", bg = "#1e1e2e" },
          NoicePopupTitle = { fg = "#f38ba8", bg = "#1e1e2e", bold = true },
          NoiceCmdline = { bg = "#181825", fg = "#cdd6f4" },
          NoiceCmdlinePopup = { bg = "#1e1e2e", fg = "#cdd6f4" },
          NoiceCmdlinePopupBorder = { fg = "#89b4fa", bg = "#1e1e2e" },
          NoiceConfirm = { bg = "#1e1e2e", fg = "#cdd6f4" },
          NoiceConfirmBorder = { fg = "#a6e3a1", bg = "#1e1e2e" },
        }

        for group, opts_hl in pairs(highlights) do
          vim.api.nvim_set_hl(0, group, opts_hl)
        end
      end,
    })

    -- Trigger initial setup
    vim.cmd("doautocmd ColorScheme")
  end,
}
